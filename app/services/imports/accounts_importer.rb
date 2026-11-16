module Imports
  # Idempotent import of an Apollo accounts CSV. A row that is the same company as one we have
  # (same Apollo id, same website, or same name+city+country) updates or merges into it instead of duplicating.
  class AccountsImporter
    MERGED_NOTE = "rows_merged_into_existing_company".freeze

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
    rescue StandardError
      batch&.update(status: "failed")
      raise
    end

    private

    def import_row(batch, tally, line, row)
      tally.row!
      parsed = AccountRow.new(row)
      attrs = parsed.attributes
      reason = skip_reason(attrs)
      return tally.skip!(line, reason) if reason

      if (company = find_same_company(attrs))
        save(tally, line, company, attrs, parsed.extra)
      elsif (twin = find_duplicate(attrs))
        merge(tally, line, twin, attrs, parsed.extra)
      else
        save(tally, line, Company.new(import_batch: batch), attrs, parsed.extra)
      end
    end

    def skip_reason(attrs)
      return "missing_name" if attrs[:name].blank?
      "missing_identifier" if attrs[:apollo_account_id].blank? && attrs[:domain].blank?
    end

    # The same company: same Apollo Account Id, or the same website where the two ids don't disagree.
    def find_same_company(attrs)
      if attrs[:apollo_account_id]
        by_id = Company.find_by(apollo_account_id: attrs[:apollo_account_id])
        return by_id if by_id
      end
      return nil unless attrs[:domain]

      by_domain = Company.find_by(domain: attrs[:domain])
      by_domain unless by_domain&.apollo_account_id && attrs[:apollo_account_id]
    end

    # A duplicate of an existing company under a different Apollo id: an id we already folded in,
    # the same website under a different id, or the same name in the same city and country.
    def find_duplicate(attrs)
      alternate_id(attrs[:apollo_account_id]) ||
        (attrs[:domain] && Company.find_by(domain: attrs[:domain])) ||
        DuplicateMatcher.call(attrs)
    end

    def alternate_id(id)
      return nil if id.blank?

      Company.find_by("extra->'alternate_apollo_account_ids' @> ?::jsonb", [ id ].to_json)
    end

    # Folds a duplicate row into the existing company without overwriting anything it already has:
    # only blank fields are filled, and the duplicate's Apollo id is remembered so a re-import is quiet.
    def merge(tally, line, company, attrs, extra)
      tally.note!(MERGED_NOTE)
      company.assign_attributes(attrs.compact.select { |field, _| company[field].blank? })
      company.extra = company.extra.merge(extra.reject { |header, _| company.extra.key?(header) })
      remember_alternate_id(company, attrs[:apollo_account_id])
      return unless company.changed?

      company.save ? tally.updated! : tally.skip!(line, "invalid_row")
    end

    def remember_alternate_id(company, id)
      return if id.blank? || id == company.apollo_account_id

      known = Array(company.extra["alternate_apollo_account_ids"])
      company.extra = company.extra.merge("alternate_apollo_account_ids" => (known | [ id ]))
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
