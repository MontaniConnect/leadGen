module Exports
  # Builds one Export's file from its filters and stores it. Failures are recorded on the export
  # (so the page can show them) instead of raised.
  class Runner
    def initialize(row: Row.new, writers: { "csv" => CsvWriter.new, "xlsx" => XlsxWriter.new })
      @row = row
      @writers = writers
    end

    def call(export)
      export.update!(status: "running", error: nil)
      companies = export.queue.scope.preload(:evaluations, :selected_contact, :messages).to_a
      data = @writers.fetch(export.file_format).call(Row::HEADERS, companies.map { |company| @row.values(company) })
      export.update!(status: "done", row_count: companies.size, data: data, filename: filename(export),
                     content_type: Export::FORMATS.fetch(export.file_format)[:content_type])
    rescue StandardError => e
      Rails.error.report(e, handled: true)
      export.update!(status: "failed", error: "#{e.class.name.demodulize}: #{e.message}".truncate(300))
    ensure
      export
    end

    private

    def filename(export)
      slug = export.scope == "all" ? "all" : export.queue.tier.downcase
      "montani-leads-#{slug}-#{Date.current.iso8601}.#{export.extension}"
    end
  end
end
