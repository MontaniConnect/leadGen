module Exports
  # One export row for a lead. Column order is the contract with the sheet people work in.
  class Row
    HEADERS = [
      "Company", "URL", "Contact", "Title", "Contact LinkedIn URL", "Staffing score", "Automation score",
      "Confidence", "Tier", "Why now", "Lead with", "Message variant 1", "Message variant 2",
      "Message variant 3", "Key source URL", "Reply Result",
      "Apollo Account Id" # not in the original spec: the key reply re-import matches on
    ].freeze
    VARIANT_ORDER = %w[curious_question founder_time low_pressure_offer].freeze

    def values(company)
      evaluation = company.current_evaluation
      contact = company.selected_contact
      messages = company.messages.index_by(&:label)
      [
        company.name, website(company), contact&.full_name, contact&.title,
        Leads::LinkedinTarget.call(company).url, evaluation.staffing_score, evaluation.automation_score,
        evaluation.confidence, evaluation.tier, evaluation.why_now, evaluation.lead_with,
        *VARIANT_ORDER.map { |label| messages[label]&.body },
        key_source_url(evaluation), Company::REPLY_RESULTS[company.reply_result], company.apollo_account_id
      ].map { |value| value.nil? ? "" : value }
    end

    private

    def website(company)
      url = company.website.presence || company.domain.presence
      return nil unless url

      url.match?(%r{\Ahttps?://}i) ? url : "https://#{url}"
    end

    # The first evidence link: a top signal's page, else the why-now source. Apollo fields are not URLs.
    def key_source_url(evaluation)
      sources = Array(evaluation.signals).map { |signal| signal["source"] } + [ evaluation.why_now_source ]
      sources.filter_map { |source| Leads::LinkedinTarget.web_url(source) }.first
    end
  end
end
