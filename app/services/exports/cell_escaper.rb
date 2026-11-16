module Exports
  # Spreadsheet-injection defence. A text cell that starts with = + - @ (or a tab or carriage return)
  # would be run as a formula by Excel, Sheets or LibreOffice. A leading apostrophe makes it plain text.
  module CellEscaper
    DANGEROUS_START = /\A[=+\-@\t\r]/

    def self.call(value)
      return value unless value.is_a?(String)

      value.match?(DANGEROUS_START) ? "'#{value}" : value
    end
  end
end
