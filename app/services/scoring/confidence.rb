module Scoring
  # Evidence strength, counted from what we actually hold: fetched pages with useful text,
  # plus the Apollo profile when it has a description or keywords. Missing pages count as zero.
  class Confidence
    Result = Data.define(:level, :useful_sources)

    def initialize(high_min: Setting.get("scoring.confidence_high_min_sources"),
                   medium_min: Setting.get("scoring.confidence_medium_min_sources"))
      @high_min = high_min
      @medium_min = medium_min
    end

    def call(company)
      count = company.pages.count { |page| page.status == "ok" } + (apollo_profile_useful?(company) ? 1 : 0)
      level = if count >= @high_min then "High"
      elsif count >= @medium_min then "Medium"
      else "Low"
      end
      Result.new(level: level, useful_sources: count)
    end

    private

    def apollo_profile_useful?(company)
      company.short_description.present? || company.keywords.present?
    end
  end
end
