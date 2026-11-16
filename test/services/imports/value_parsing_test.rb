require "test_helper"

class Imports::ValueParsingTest < ActiveSupport::TestCase
  test "domain normalizer" do
    assert_equal "acme.com", Imports::DomainNormalizer.call("https://www.Acme.com/about")
    assert_equal "beta.io", Imports::DomainNormalizer.call("beta.io")
    assert_nil Imports::DomainNormalizer.call("  ")
  end

  test "money and integers" do
    assert_equal 1_200_000, Imports::ValueParser.money("$1.2M")
    assert_equal 350_000, Imports::ValueParser.money("350K")
    assert_nil Imports::ValueParser.money("n/a")
    assert_equal 1200, Imports::ValueParser.integer("1,200")
    assert_nil Imports::ValueParser.integer("")
    assert_nil Imports::ValueParser.date("garbage")
  end
end
