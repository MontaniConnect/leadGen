module Imports
  # Maps one Apollo accounts CSV row to Company attributes.
  # Headers are matched loosely ("# Employees", "Employees" ...); unknown columns go to `extra`.
  class AccountRow
    P = ValueParser
    COLUMNS = {
      "companyname" => [ :name, :text ], "name" => [ :name, :text ],
      "accountstage" => [ :account_stage, :text ],
      "employees" => [ :employees, :integer ], "numberofemployees" => [ :employees, :integer ],
      "industry" => [ :industry, :text ], "website" => [ :website, :text ],
      "companylinkedinurl" => [ :linkedin_url, :text ],
      "companycity" => [ :city, :text ], "companystate" => [ :state, :text ],
      "companycountry" => [ :country, :text ],
      "keywords" => [ :keywords, :text ], "technologies" => [ :technologies, :text ],
      "totalfunding" => [ :total_funding, :money ], "latestfunding" => [ :latest_funding, :text ],
      "latestfundingamount" => [ :latest_funding_amount, :money ],
      "lastraisedat" => [ :last_raised_at, :date ], "annualrevenue" => [ :annual_revenue, :money ],
      "apolloaccountid" => [ :apollo_account_id, :text ],
      "siccodes" => [ :sic_codes, :text ], "naicscodes" => [ :naics_codes, :text ],
      "shortdescription" => [ :short_description, :text ], "foundedyear" => [ :founded_year, :integer ],
      "primaryintenttopic" => [ :intent_topic, :text ], "primaryintentscore" => [ :intent_score, :integer ]
    }.freeze

    def initialize(row)
      @row = row
    end

    def attributes
      @attributes ||= build.merge(domain: Imports::DomainNormalizer.call(build[:website]))
    end

    def extra
      @extra ||= @row.reject { |header, value| COLUMNS.key?(normalize(header)) || value.to_s.strip.empty? }
    end

    private

    def build
      @build ||= @row.each_with_object({}) do |(header, value), attrs|
        attribute, parser = COLUMNS[normalize(header)]
        attrs[attribute] = P.public_send(parser, value) if attribute
      end
    end

    def normalize(header)
      header.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end
  end
end
