require "csv"

module Exports
  # CSV with a UTF-8 byte-order mark so Excel reads accents correctly. Every text cell is escaped.
  class CsvWriter
    BOM = "\uFEFF".freeze

    def call(headers, rows)
      body = CSV.generate do |csv|
        csv << headers
        rows.each { |row| csv << row.map { |value| CellEscaper.call(value) } }
      end
      BOM + body
    end
  end
end
