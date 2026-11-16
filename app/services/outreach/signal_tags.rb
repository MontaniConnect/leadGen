module Outreach
  # Short, deterministic tags describing a lead's top signals, so results can later show which kinds of
  # evidence tend to get replies: where each signal came from (apollo, or the kind of page), plus
  # offshore openness and regulated data.
  class SignalTags
    REGULATED = /hipaa|patient|regulated|\bphi\b|\bbaa\b/i
    NOT_FOUND = "not found".freeze

    def self.call(company, evaluation)
      tags = Array(evaluation.signals).first(3).map { |signal| source_tag(signal["source"], company) }
      tags << "offshore_openness" if present?(evaluation.offshore_signal)
      tags << "regulated_data" if Array(evaluation.red_flags).any? { |flag| flag["flag"].to_s.match?(REGULATED) }
      tags.uniq
    end

    def self.source_tag(source, company)
      text = source.to_s.strip
      return "apollo" if text.downcase.start_with?("apollo")

      page = company.pages.find { |candidate| candidate.url == text }
      page ? page.kind : "other"
    end

    def self.present?(text) = text.present? && text.strip.downcase != NOT_FOUND
  end
end
