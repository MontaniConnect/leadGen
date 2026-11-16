require "nokogiri"

module Fetching
  # Finds a leader on an about/team page: "Jane Doe, CEO" in one block, or a name block next to a title block.
  # Deliberately strict. It returns nothing rather than a guess.
  class SiteContactExtractor
    NAME = /\A[[:upper:]][[:alpha:]'’.-]+(?: [[:upper:]][[:alpha:]'’.-]+){1,2}\z/
    LEAF_BLOCKS = "h1, h2, h3, h4, h5, h6, p, li, div, span, strong, b".freeze
    MAX_TITLE_LENGTH = 60
    ACCEPTED_TIERS = 3 # CEO/founder, CTO, head of engineering/operations

    def initialize(ranker: Contacts::TitleRanker.from_settings)
      @ranker = ranker
    end

    # Returns { first_name:, last_name:, title: } or nil.
    def call(html)
      blocks = leaf_texts(Nokogiri::HTML(html))
      candidates = blocks.each_index.filter_map { |i| candidate_at(blocks, i) }
      candidates.min_by { |c| c[:rank] }&.except(:rank)
    end

    private

    def leaf_texts(doc)
      doc.css("nav, header, footer, script, style").remove
      doc.css(LEAF_BLOCKS).select { |el| el.css(LEAF_BLOCKS).empty? }
         .map { |el| el.text.gsub(/\s+/, " ").strip }.reject(&:empty?)
    end

    def candidate_at(blocks, index)
      text = blocks[index]
      return nil if text.length > MAX_TITLE_LENGTH + 40

      inline(text) || adjacent(blocks, index)
    end

    # "Jane Doe, CEO" / "Jane Doe - Founder & CEO" / "Jane Doe | CTO"
    def inline(text)
      name, title = text.split(/\s*[,|–—-]\s+/, 2)
      build(name, title)
    end

    # Title in this block, name in the previous or next block.
    def adjacent(blocks, index)
      neighbours = [ index - 1, index + 1 ].select { |i| i.between?(0, blocks.size - 1) }
      neighbours.each do |i|
        built = build(blocks[i], blocks[index])
        return built if built
      end
      nil
    end

    def build(name, title)
      return nil unless name.to_s.match?(NAME) && !title_like?(name)
      return nil unless title.present? && title.length <= MAX_TITLE_LENGTH

      rank = @ranker.rank(title)
      return nil unless rank && rank < ACCEPTED_TIERS

      first, *rest = name.split
      { first_name: first, last_name: rest.join(" "), title: title, rank: rank }
    end

    # "Chief Executive Officer" or "Our Founder" must not be mistaken for a person's name.
    def title_like?(text)
      rank = @ranker.rank(text)
      rank.nil? || rank < ACCEPTED_TIERS
    end
  end
end
