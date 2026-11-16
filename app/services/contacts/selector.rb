module Contacts
  # Picks the best contact for one company. A contact a person added by hand always wins (they researched
  # it, so it is never swapped for an automatic pick). Otherwise: best title tier, then has a LinkedIn URL, then oldest.
  class Selector
    def initialize(ranker: TitleRanker.from_settings)
      @ranker = ranker
    end

    def call(company)
      ranked = company.contacts.filter_map do |contact|
        rank = @ranker.rank(contact.title)
        [ [ contact.source == "manual" ? 0 : 1, rank, contact.linkedin_url.present? ? 0 : 1, contact.id ], contact ] if rank
      end
      ranked.min_by(&:first)&.last
    end
  end
end
