module Imports
  # Idempotent import of an Apollo People CSV, joined to companies by Apollo Account Id.
  class PeopleImporter
    COLUMNS = {
      "firstname" => :first_name, "lastname" => :last_name, "title" => :title,
      "personlinkedinurl" => :linkedin_url, "linkedinurl" => :linkedin_url, "email" => :email
    }.freeze

    def initialize(path, rows: nil)
      @path = path
      @rows = rows || CsvRows.new(path)
    end

    def call
      batch = ImportBatch.create!(kind: "people", filename: File.basename(@path), status: "running")
      tally = Tally.new
      @rows.each { |line, row| import_row(tally, line, row) }
      tally.apply_to(batch)
      batch
    rescue StandardError
      batch&.update(status: "failed")
      raise
    end

    private

    def import_row(tally, line, row)
      tally.row!
      attrs = attributes(row)
      return tally.skip!(line, "missing_name") if attrs[:first_name].blank? && attrs[:last_name].blank?

      company = Company.find_by(apollo_account_id: account_id(row))
      return tally.skip!(line, "unknown_company") unless company

      save(tally, line, find_contact(company, attrs), attrs)
    end

    def attributes(row)
      row.each_with_object({}) do |(header, value), attrs|
        attribute = COLUMNS[header.to_s.downcase.gsub(/[^a-z0-9]/, "")]
        attrs[attribute] = ValueParser.text(value) if attribute
      end
    end

    def account_id(row)
      row.find { |header, _| header.to_s.downcase.gsub(/[^a-z0-9]/, "") == "apolloaccountid" }&.last.to_s.strip
    end

    def find_contact(company, attrs)
      scope = company.contacts
      by_url = attrs[:linkedin_url] && scope.find_by(linkedin_url: attrs[:linkedin_url])
      by_url || scope.find_by(first_name: attrs[:first_name], last_name: attrs[:last_name]) ||
        scope.new(source: "apollo")
    end

    def save(tally, line, contact, attrs)
      new_record = contact.new_record?
      contact.assign_attributes(attrs.compact)
      return unless new_record || contact.changed?

      if contact.save
        new_record ? tally.created! : tally.updated!
      else
        tally.skip!(line, "invalid_row")
      end
    end
  end
end
