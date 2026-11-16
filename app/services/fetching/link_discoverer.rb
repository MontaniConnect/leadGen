require "nokogiri"
require "uri"

module Fetching
  # Finds the about, careers and blog pages from the home page's own links (same host only).
  class LinkDiscoverer
    PATTERNS = {
      "about" => %w[about our-story who-we-are company leadership team],
      "careers" => %w[careers career jobs join-us work-with-us hiring],
      "blog" => %w[blog insights news resources]
    }.freeze
    SKIPPED_EXTENSIONS = /\.(pdf|jpe?g|png|gif|zip|docx?|xlsx?)\z/i

    def call(html, base_url)
      base = URI.parse(base_url)
      candidates = anchors(Nokogiri::HTML(html), base)
      PATTERNS.each_with_object({}) do |(kind, patterns), found|
        best = candidates.filter_map { |c| score(c, patterns) }.min_by(&:first)
        found[kind] = best.last[:url] if best
      end
    end

    private

    # [{url:, text:, path:, in_nav:}] for same-host http(s) links, fragments stripped, home excluded.
    def anchors(doc, base)
      doc.css("a[href]").filter_map do |a|
        uri = resolve(base, a["href"])
        next unless uri && uri.host == base.host && uri.path.to_s.length > 1 && uri.path !~ SKIPPED_EXTENSIONS

        { url: uri.to_s, text: a.text.to_s.downcase, path: uri.path.downcase,
          in_nav: a.ancestors.any? { |n| %w[nav header].include?(n.name) } }
      end
    end

    def resolve(base, href)
      uri = URI.join(base.to_s, href.to_s.strip)
      return nil unless %w[http https].include?(uri.scheme)

      uri.fragment = nil
      uri.query = nil
      uri
    rescue URI::Error
      nil
    end

    def score(candidate, patterns)
      index = patterns.index { |p| candidate[:path].split("/").any? { |seg| seg.include?(p) } || candidate[:text].strip == p }
      return nil unless index

      [ [ index, candidate[:in_nav] ? 0 : 1, candidate[:path].length ], candidate ]
    end
  end
end
