module Imports
  # Counts what happened to each row and why rows were skipped.
  class Tally
    MAX_SKIPPED_ROWS = 200

    attr_reader :total, :created, :updated, :skip_reasons, :skipped_rows, :notes

    def initialize
      @total = @created = @updated = 0
      @skip_reasons = Hash.new(0)
      @skipped_rows = []
      @notes = Hash.new(0)
    end

    def row! = @total += 1
    def created! = @created += 1
    def updated! = @updated += 1

    # An FYI about a row that was still processed (not a skip).
    def note!(reason) = @notes[reason] += 1

    def skip!(line, reason)
      @skip_reasons[reason] += 1
      @skipped_rows << { line: line, reason: reason } if @skipped_rows.size < MAX_SKIPPED_ROWS
    end

    def skipped = skip_reasons.values.sum
    def unchanged = total - created - updated - skipped

    def apply_to(batch)
      batch.update!(
        status: "complete", rows_total: total, rows_created: created, rows_updated: updated,
        rows_skipped: skipped, skip_reasons: skip_reasons, skipped_rows: skipped_rows, notes: notes
      )
    end
  end
end
