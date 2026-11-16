module Partnering
  # The per-firm <partner> block: contact, Apollo facts, why it is a partner candidate, and any page text.
  class EvidenceFormatter
    FIELD_LIMIT = 500

    def initialize(page_words: 400)
      @page_words = page_words
    end

    def call(company)
      <<~TEXT
        <partner>
        Company: #{company.name} (#{company.website.presence || company.domain.presence || 'no website'})
        Contact first name: #{company.selected_contact&.first_name.presence || 'none'}
        Contact title: #{company.selected_contact&.title.presence || 'Not found'}
        #{facts(company)}
        Why this is a partner candidate: #{reason(company)}
        #{pages(company)}
        </partner>

        Write the message.
      TEXT
    end

    def reason(company)
      evaluation = company.current_evaluation
      return "Scored as a competitor: #{evaluation.red_flags.first&.dig('flag')}" if evaluation&.disqualified

      kinds = company.prefilter_reasons.grep(/excluded_/).map { |reason| reason.sub(/excluded_(keyword|naics): /, "") }
      "Apollo lists it under #{kinds.join(', ')} (staffing, recruiting or outsourcing)"
    end

    private

    def facts(company)
      {
        "Industry" => company.industry, "Employees" => company.employees, "Location" => [ company.city, company.country ].compact_blank.join(", "),
        "Keywords" => company.keywords, "Description" => company.short_description
      }.filter_map { |label, value| "#{label}: #{value.to_s.squish.truncate(FIELD_LIMIT)}" if value.present? }.join("\n")
    end

    def pages(company)
      company.pages.select { |page| page.status == "ok" && page.text.present? }.map do |page|
        %(<page kind="#{page.kind}" source="#{page.url}">\n#{page.text.split.first(@page_words).join(' ')}\n</page>)
      end.join("\n")
    end
  end
end
