module Imports
  # Human-readable report for an ImportBatch.
  class Summary
    def initialize(batch)
      @batch = batch
    end

    def to_s
      lines = [
        "Import ##{@batch.id} (#{@batch.kind}, #{@batch.filename})",
        "  rows read:  #{@batch.rows_total}",
        "  created:    #{@batch.rows_created}",
        "  updated:    #{@batch.rows_updated}",
        "  unchanged:  #{@batch.rows_unchanged}",
        "  skipped:    #{@batch.rows_skipped}"
      ]
      @batch.skip_reasons.each { |reason, count| lines << "    - #{reason}: #{count}" }
      @batch.notes.each { |reason, count| lines << "  note: #{reason}: #{count}" }
      lines.join("\n")
    end
  end
end
