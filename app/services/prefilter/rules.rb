module Prefilter
  # The filter rules as a plain value object. Build from Settings, or by hand in tests.
  Rules = Data.define(
    :min_employees, :max_employees, :countries, :excluded_naics_prefixes, :excluded_keywords,
    :excluded_keyword_fields, :boost_technologies, :boost_keywords, :intent_min_score,
    :why_now_funding_days
  ) do
    def self.from_settings
      new(**members.index_with { |name| Setting.get("prefilter.#{name}") })
    end
  end
end
