require "csv"

module Imports
  # Streams a CSV as [line_number, {original_header => value}] pairs. Tolerates a BOM.
  class CsvRows
    include Enumerable

    def initialize(path)
      @path = path
    end

    # A reproducible random sample of rows (same seed, same rows), kept in file order.
    def sample(count, seed: 42)
      to_a.sample(count, random: Random.new(seed)).sort_by(&:first)
    end

    def each
      CSV.foreach(@path, headers: true, encoding: "bom|utf-8").with_index(2) do |row, line|
        yield line, row.to_h
      end
    end
  end
end
