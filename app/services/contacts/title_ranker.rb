module Contacts
  # Ranks a job title: 0 is best. Returns nil when the title must never be selected.
  class TitleRanker
    def initialize(tiers:, excluded_words:)
      @tiers = tiers
      @excluded_words = excluded_words
    end

    def self.from_settings
      new(tiers: Setting.get("contacts.title_tiers"), excluded_words: Setting.get("contacts.excluded_title_words"))
    end

    def rank(title)
      return nil if matches_any?(title, @excluded_words)

      @tiers.index { |patterns| matches_any?(title, patterns) } || @tiers.size
    end

    private

    def matches_any?(title, patterns)
      patterns.any? { |pattern| title.to_s.match?(/(?<![[:alnum:]])#{Regexp.escape(pattern)}(?![[:alnum:]])/i) }
    end
  end
end
