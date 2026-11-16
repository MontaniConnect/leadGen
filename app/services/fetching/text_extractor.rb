require "nokogiri"

module Fetching
  # Readable text from HTML: drops scripts, styles and page chrome, collapses whitespace,
  # and truncates to max_words.
  class TextExtractor
    NOISE = "script, style, noscript, template, svg, iframe, nav, header, footer, aside, form, [role=navigation]".freeze

    def initialize(max_words:)
      @max_words = max_words
    end

    def call(html)
      doc = Nokogiri::HTML(html)
      doc.css(NOISE).remove
      words = doc.at_css("body")&.xpath(".//text()").to_a.map(&:text).join(" ").split
      words.to_a.first(@max_words).join(" ")
    end
  end
end
