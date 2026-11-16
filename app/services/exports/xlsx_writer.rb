require "axlsx"

module Exports
  # XLSX where every text cell is written as a string cell (never a formula) and escaped as well.
  # Scores are numeric so the sheet sorts properly.
  class XlsxWriter
    COLUMN_WIDTHS = [ 24, 28, 20, 20, 36, 10, 10, 11, 8, 36, 36, 50, 50, 50, 36, 14, 18 ].freeze

    def call(headers, rows)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "Leads") do |sheet|
        header_style = sheet.styles.add_style(b: true, bg_color: "E6F1F0")
        body_style = sheet.styles.add_style(alignment: { wrap_text: true, vertical: :top })
        sheet.add_row headers, style: header_style, types: [ :string ] * headers.size
        rows.each do |row|
          sheet.add_row row.map { |value| CellEscaper.call(value) }, style: body_style,
                                                                   types: row.map { |value| value.is_a?(Integer) ? :integer : :string }
        end
        sheet.column_widths(*COLUMN_WIDTHS)
        sheet.sheet_view.pane { |pane| pane.state = :frozen; pane.y_split = 1; pane.top_left_cell = "A2" }
      end
      package.to_stream.read
    end
  end
end
