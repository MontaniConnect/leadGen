require "test_helper"

class Exports::WritersTest < ActiveSupport::TestCase
  HEADERS = [ "Company", "Score", "Note" ].freeze
  ROWS = [
    [ "=HYPERLINK(\"http://evil.example\",\"click\")", 8, "Hi, \"quoted\" and, commas" ],
    [ "+1+1", 7, "@SUM(A1)" ],
    [ "-5 off", 6, "multi\nline note" ],
    [ "Plain Co", 5, "" ]
  ].freeze

  test "CSV starts with a BOM, round-trips awkward text, and neutralises formulas" do
    data = Exports::CsvWriter.new.call(HEADERS, ROWS)

    assert data.start_with?("\uFEFF")
    parsed = CSV.parse(data.delete_prefix("\uFEFF"))
    assert_equal HEADERS, parsed.first
    assert_equal [ "'=HYPERLINK(\"http://evil.example\",\"click\")", "8", "Hi, \"quoted\" and, commas" ], parsed[1]
    assert_equal [ "'+1+1", "7", "'@SUM(A1)" ], parsed[2]
    assert_equal [ "'-5 off", "6", "multi\nline note" ], parsed[3]
    assert_equal [ "Plain Co", "5", "" ], parsed[4]
    parsed.flatten.each { |cell| assert_no_match(/\A[=+\-@]/, cell) }
  end

  test "XLSX stores no formulas, writes text as string cells and scores as numbers" do
    cells = XlsxReader.cells(Exports::XlsxWriter.new.call(HEADERS, ROWS))

    assert_equal 5, cells.size
    assert_empty cells.flatten.select(&:formula), "no cell may contain a formula"
    first = cells[1]
    assert_equal "'=HYPERLINK(\"http://evil.example\",\"click\")", first[0].value
    assert_includes %w[s inlineStr str], first[0].type
    assert_equal "n", first[1].type, "scores are numeric cells"
    assert_equal "8", first[1].value
    assert_equal "'@SUM(A1)", cells[2][2].value
    assert_equal "'-5 off", cells[3][0].value
    assert_equal "multi\nline note", cells[3][2].value
  end

  test "XLSX does not turn digit-like text into numbers" do
    cells = XlsxReader.cells(Exports::XlsxWriter.new.call([ "Phone" ], [ [ "007" ], [ "1E5" ] ]))
    assert_equal [ "007", "1E5" ], cells.drop(1).map { |row| row[0].value }
  end

  test "headers are the first row in both formats" do
    assert_equal HEADERS, XlsxReader.rows(Exports::XlsxWriter.new.call(HEADERS, [])).first
    assert_equal [ HEADERS ], CSV.parse(Exports::CsvWriter.new.call(HEADERS, []).delete_prefix("\uFEFF"))
  end
end
