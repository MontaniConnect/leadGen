module Scoring
  # Turns a company's Apollo record and fetched pages into the per-company part of the prompt.
  class EvidenceFormatter
    APOLLO_FIELDS = {
      "Company Name" => :name, "Industry" => :industry, "# Employees" => :employees, "Website" => :website,
      "City" => :city, "State" => :state, "Country" => :country, "Founded Year" => :founded_year,
      "Short Description" => :short_description, "Keywords" => :keywords, "Technologies" => :technologies,
      "Latest Funding" => :latest_funding, "Latest Funding Amount" => :latest_funding_amount,
      "Last Raised At" => :last_raised_at, "Total Funding" => :total_funding, "Annual Revenue" => :annual_revenue,
      "Account Stage" => :account_stage, "Primary Intent Topic" => :intent_topic, "Primary Intent Score" => :intent_score
    }.freeze
    FIELD_LIMIT = 600
    PAGE_ORDER = %w[home about careers blog].freeze

    def initialize(words_per_page: Setting.get("scoring.prompt_words_per_page"), today: Date.current)
      @words_per_page = words_per_page
      @today = today
    end

    def call(company)
      <<~TEXT
        Today's date: #{@today.iso8601}

        <company_data>
        <apollo>
        #{apollo_lines(company)}
        </apollo>
        #{page_blocks(company)}
        </company_data>

        Assess this company.
      TEXT
    end

    private

    def apollo_lines(company)
      APOLLO_FIELDS.filter_map do |label, attribute|
        value = company.public_send(attribute)
        "#{label}: #{value.to_s.squish.truncate(FIELD_LIMIT)}" if value.present?
      end.join("\n")
    end

    def page_blocks(company)
      pages = company.pages.select { |page| page.status == "ok" && page.text.present? }
      pages.sort_by { |page| PAGE_ORDER.index(page.kind) || PAGE_ORDER.size }.map do |page|
        %(<page kind="#{page.kind}" source="#{page.url}">\n#{page.text.split.first(@words_per_page).join(' ')}\n</page>)
      end.join("\n")
    end
  end
end
