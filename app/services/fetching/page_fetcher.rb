module Fetching
  # Fetches one URL politely: robots.txt, rate limit, then a GET. Maps every outcome to a status.
  class PageFetcher
    def initialize(http:, limiter:, robots:)
      @http = http
      @limiter = limiter
      @robots = robots
    end

    def call(url)
      return result("blocked", nil, "", url) unless @robots.allowed?(url)

      @limiter.wait(URI.parse(url).host)
      reply = @http.get(url)
      result(status_for(reply), reply.status, reply.body, reply.url.presence || url)
    end

    private

    def status_for(reply)
      return reply.error.to_s if reply.error # "timeout" or "network"
      return "ok" if reply.status == 200 && reply.content_type.include?("html")
      return "not_found" if [ 404, 410 ].include?(reply.status)
      return "blocked" if [ 401, 403, 429 ].include?(reply.status)

      "error"
    end

    def result(status, http_status, body, url)
      FetchedPage.new(status: status == "network" ? "error" : status, http_status: http_status,
                      html: status == "ok" ? body : "", url: url)
    end
  end
end
