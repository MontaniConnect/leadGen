require "csv"

module Pilot
  # Step 1 of the pilot: import a random sample of rows, run the prefilter, and print every Pass/Fail
  # decision with its reason so a person can check them by hand. Also writes a CSV with an empty
  # "Your verdict" column to mark up. Safe to repeat with the same file and seed (nothing duplicates).
  class Intake
    HEADERS = [ "Company", "Website", "Employees", "Country", "Industry", "Result", "Reasons", "Boosts", "Your verdict" ].freeze

    def initialize(path:, count: 20, seed: 42, out: $stdout, csv_path: Rails.root.join("tmp/pilot_prefilter.csv"))
      @path = path
      @count = count
      @seed = seed
      @out = out
      @csv_path = csv_path
    end

    def call
      rows = Imports::CsvRows.new(@path).sample(@count, seed: @seed)
      batch = Imports::AccountsImporter.new(@path, rows: rows).call
      Setting.set("pilot.company_ids", company_ids(rows))
      Prefilter::Runner.new(scope: Pilot.scope).call
      @out.puts Imports::Summary.new(batch)
      print_table
      write_csv
      batch
    end

    private

    def company_ids(rows)
      rows.filter_map do |_line, row|
        attrs = Imports::AccountRow.new(row).attributes
        (attrs[:apollo_account_id] && Company.find_by(apollo_account_id: attrs[:apollo_account_id]) ||
          (attrs[:domain] && Company.find_by(domain: attrs[:domain])))&.id
      end.uniq
    end

    def companies = Pilot.scope.order(:prefilter_status, :name)

    def print_table
      @out.puts "", format("%-3s %-28s %5s  %-14s %s", "", "Company", "Emp", "Country", "Why")
      companies.each do |company|
        why = (company.prefilter_status == "fail" ? company.prefilter_reasons : company.prefilter_boosts).join(", ")
        @out.puts format("%-4s %-28s %5s  %-14s %s", company.prefilter_status == "pass" ? "PASS" : "FAIL",
                         company.name.to_s.truncate(28), company.employees, company.country.to_s.truncate(14), why)
      end
      @out.puts "", "Check each decision by hand. To change a rule: Setting.set(\"prefilter.min_employees\", 15), then bin/rails prefilter:run",
                "Spreadsheet to mark up: #{@csv_path}"
    end

    def write_csv
      FileUtils.mkdir_p(File.dirname(@csv_path))
      CSV.open(@csv_path, "w") do |csv|
        csv << HEADERS
        companies.each do |company|
          csv << [ company.name, company.website, company.employees, company.country, company.industry,
                   company.prefilter_status.upcase, company.prefilter_reasons.join("; "), company.prefilter_boosts.join("; "), "" ]
        end
      end
    end
  end
end
