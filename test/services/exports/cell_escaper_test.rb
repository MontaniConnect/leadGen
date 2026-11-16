require "test_helper"

class Exports::CellEscaperTest < ActiveSupport::TestCase
  def esc(value) = Exports::CellEscaper.call(value)

  test "text starting with = + - @ tab or carriage return gets a leading apostrophe" do
    [ "=SUM(A1:A9)", "+1+1", "-2+3", "@cmd", "\t=1+1", "\r=1+1", "=HYPERLINK(\"http://evil\",\"x\")" ].each do |dangerous|
      assert_equal "'#{dangerous}", esc(dangerous)
    end
  end

  test "ordinary text, numbers, nil and mid-string symbols are untouched" do
    assert_equal "Hi Ada, 2+2 = 4?", esc("Hi Ada, 2+2 = 4?")
    assert_equal "Acme - Inc", esc("Acme - Inc")
    assert_equal 8, esc(8)
    assert_nil esc(nil)
    assert_equal "", esc("")
  end
end
