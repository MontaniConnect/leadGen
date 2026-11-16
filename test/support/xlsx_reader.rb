require "zip"
require "nokogiri"

# Reads an XLSX binary back into raw cell facts, so tests can prove what was actually stored
# (string vs number vs formula), not just what a spreadsheet app would display.
module XlsxReader
  Cell = Struct.new(:ref, :type, :value, :formula)

  def self.cells(data)
    sheet = nil
    shared = []
    Zip::File.open_buffer(StringIO.new(data)) do |zip|
      sheet = Nokogiri::XML(zip.read("xl/worksheets/sheet1.xml")).remove_namespaces!
      shared_entry = zip.find_entry("xl/sharedStrings.xml")
      shared = Nokogiri::XML(shared_entry.get_input_stream.read).remove_namespaces!.xpath("//si").map(&:text) if shared_entry
    end
    sheet.xpath("//row").map do |row|
      row.xpath("c").map do |c|
        type = c["t"]
        value = case type
        when "s" then shared[c.at_xpath("v").text.to_i]
        when "inlineStr" then c.at_xpath("is").text
        else c.at_xpath("v")&.text
        end
        Cell.new(c["r"], type, value, c.at_xpath("f")&.text)
      end
    end
  end

  def self.rows(data) = cells(data).map { |row| row.map(&:value) }
end
