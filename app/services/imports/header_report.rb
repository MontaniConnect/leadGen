require "csv"

module Imports
  # Reads only the header row of an upload and says whether it looks like the right kind of Apollo file,
  # which columns will be used, and which will just be kept as extra data. Catches the wrong file (or a
  # renamed column) before anything is imported, instead of after every company fails the prefilter.
  class HeaderReport
    Result = Data.define(:headers, :recognised, :unrecognised, :missing_required, :warnings) do
      def ok? = missing_required.empty?
    end

    # needs: groups of acceptable normalized headers; at least one per group must be present.
    KINDS = {
      accounts: {
        known: AccountRow::COLUMNS.keys,
        required: { "Company Name" => %w[companyname name], "Apollo Account Id or Website" => %w[apolloaccountid website] },
        warn: { "# Employees" => %w[employees numberofemployees], "Company Country" => %w[companycountry country] }
      },
      people: {
        known: PeopleImporter::COLUMNS.keys + %w[apolloaccountid],
        required: { "Apollo Account Id" => %w[apolloaccountid], "First Name or Last Name" => %w[firstname lastname] },
        warn: { "Title" => %w[title], "Person Linkedin Url" => %w[personlinkedinurl linkedinurl] }
      }
    }.freeze

    def initialize(kind)
      @config = KINDS.fetch(kind)
    end

    def call(path)
      headers = read_headers(path)
      normalized = headers.to_h { |header| [ normalize(header), header ] }
      recognised, unrecognised = headers.partition { |header| @config[:known].include?(normalize(header)) }
      Result.new(
        headers: headers, recognised: recognised, unrecognised: unrecognised,
        missing_required: missing(@config[:required], normalized),
        warnings: missing(@config[:warn], normalized).map { |label| warning_for(label) }
      )
    end

    private

    def read_headers(path)
      headers = CSV.open(path, headers: true, encoding: "bom|utf-8") { |csv| csv.shift; csv.headers }
      headers.is_a?(Array) ? headers.compact : [] # an empty file has no header row
    end

    def missing(groups, normalized)
      groups.reject { |_, accepted| accepted.any? { |name| normalized.key?(name) } }.keys
    end

    def warning_for(label)
      case label
      when "# Employees" then "No employee-count column found, so every company will fail the size filter."
      when "Company Country" then "No country column found, so every company will fail the country filter."
      else "No #{label} column found."
      end
    end

    def normalize(header) = header.to_s.downcase.gsub(/[^a-z0-9]/, "")
  end
end
