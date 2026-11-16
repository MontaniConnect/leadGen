module Imports
  # Idempotent import of an Apollo accounts CSV. Dedupes on Apollo Account Id, then domain.
  class AccountsImporter
    def initialize(path, rows: nil)
      @path = path
      @rows = rows || CsvRows.new(path)
    end

    def call
      batch = ImportBatch.create!(kind: "accounts", filename: File.basename(@path), status: "running")
      tally = Tally.new
      @rows.each { |line, row| import_row(batch, tally, line, row) }
      tally.apply_to(batch)
      batch
    end

    private

    def import_row(batch, tally, line, row)
      tally.row!
      parsed = AccountRow.new(row)
      attrs = parsed.attributes
      reason = skip_reason(attrs)
      return tally.skip!(line, reason) if reason

      company = find_company(attrs)
      return tally.skip!(line, "duplicate_domain") if company == :conflict

      save(tally, line, company || Company.new(import_batch: batch), attrs, parsed.extra)
    end

    def skip_reason(attrs)
      return "missing_name" if attrs[:name].blank?
      "missing_identifier" if attrs[:apollo_account_id].blank? && attrs[:domain].blank?
    end

    # Returns a Company, nil (new), or :conflict (domain belongs to a different Apollo account).
    def find_company(attrs)
      if attrs[:apollo_account_id]
        by_id = Company.find_by(apollo_account_id: attrs[:apollo_account_id])
        return by_id if by_id
      end
      return nil unless attrs[:domain]

      by_domain = Company.find_by(domain: attrs[:domain])
      return nil unless by_domain
      return :conflict if by_domain.apollo_account_id && attrs[:apollo_account_id]

      by_domain
    end

    def save(tally, line, company, attrs, extra)
      new_record = company.new_record?
      company.assign_attributes(attrs.compact)
      company.extra = company.extra.merge(extra)
      return unless new_record || company.changed?

      if company.save
        new_record ? tally.created! : tally.updated!
      else
        tally.skip!(line, "invalid_row")
      end
    end
  end
end
