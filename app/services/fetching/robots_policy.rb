require "uri"

module Fetching
  # Answers "may we fetch this URL?" from the host's robots.txt (fetched once per host).
  # If robots.txt can't be read (5xx, timeout) we play safe and treat the host as off limits.
  class RobotsPolicy
    def initialize(http:, limiter:, user_agent:)
      @http = http
      @limiter = limiter
      @agent = user_agent.to_s.split("/").first.to_s.downcase
      @rules = {}
    end

    def allowed?(url)
      uri = URI.parse(url)
      rules = (@rules[uri.host] ||= load_rules(uri))
      return false if rules == :deny_all

      path = uri.path.presence || "/"
      path += "?#{uri.query}" if uri.query
      verdict(rules, path)
    rescue URI::InvalidURIError
      false
    end

    private

    def load_rules(uri)
      robots_url = "#{uri.scheme}://#{uri.host}/robots.txt"
      @limiter.wait(uri.host)
      reply = @http.get(robots_url)
      return :deny_all if reply.error || reply.status.to_i >= 500
      return [] unless reply.status == 200

      parse(reply.body)
    end

    # Returns [[:allow|:disallow, path_pattern], ...] for the best-matching user-agent group.
    def parse(body)
      groups = []
      current = nil
      previous_was_agent = false
      body.each_line do |raw|
        field, value = raw.sub(/#.*/, "").strip.split(":", 2).map(&:strip)
        next if field.nil? || value.nil?

        case field.downcase
        when "user-agent"
          groups << (current = { agents: [], rules: [] }) unless previous_was_agent && current
          current[:agents] << value.downcase
          previous_was_agent = true
        when "allow", "disallow"
          current[:rules] << [ field.downcase.to_sym, value ] if current
          previous_was_agent = false
        else
          previous_was_agent = false
        end
      end
      specific = groups.select { |g| g[:agents].any? { |a| a != "*" && @agent.include?(a) } }
      (specific.presence || groups.select { |g| g[:agents].include?("*") }).flat_map { |g| g[:rules] }
    end

    # Longest matching pattern wins; allow wins a tie. An empty Disallow allows everything.
    def verdict(rules, path)
      matches = rules.reject { |_, pattern| pattern.empty? }.select { |_, pattern| matches?(pattern, path) }
      best = matches.max_by { |kind, pattern| [ pattern.length, kind == :allow ? 1 : 0 ] }
      best.nil? || best.first == :allow
    end

    def matches?(pattern, path)
      regex = Regexp.escape(pattern).gsub('\*', ".*")
      regex = regex.sub('\$', "$") if pattern.end_with?("$")
      path.match?(/\A#{regex}/)
    end
  end
end
