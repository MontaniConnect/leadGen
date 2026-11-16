require "test_helper"

class Budget::PricingTest < ActiveSupport::TestCase
  def price(**args) = Budget::Pricing.new.cost(**args)

  test "Haiku: 1,000 in and 500 out is exactly $0.00035" do
    assert_equal BigDecimal("0.00035"), price(model: "claude-haiku-5-5", input: 1000, output: 500)
  end

  test "Sonnet: 5,000 in and 1,000 out is exactly $0.02" do
    assert_equal BigDecimal("0.02"), price(model: "claude-sonnet-5-5", input: 5000, output: 1000)
  end

  test "cache reads cost a tenth of input and 1-hour cache writes cost double" do
    assert_equal BigDecimal("0.000007"), price(model: "claude-haiku-5-5", input: 0, output: 0, cache_read: 700)
    assert_equal BigDecimal("0.00002"), price(model: "claude-haiku-5-5", input: 0, output: 0, cache_write: 100, cache_ttl: "1h")
    assert_equal BigDecimal("0.0000125"), price(model: "claude-haiku-5-5", input: 0, output: 0, cache_write: 100, cache_ttl: "5m")
  end

  test "all token kinds add up, and batch is half price" do
    total = price(model: "claude-haiku-5-5", input: 900, output: 150, cache_read: 700)
    assert_equal BigDecimal("0.000172"), total
    assert_equal BigDecimal("0.000086"), price(model: "claude-haiku-5-5", input: 900, output: 150, cache_read: 700, batch: true)
  end

  test "an unpriced model is an error, never a silent zero" do
    error = assert_raises(Budget::Pricing::UnknownModel) { price(model: "claude-mystery", input: 1, output: 1) }
    assert_includes error.message, "claude-mystery"
  end

  test "prices come from settings" do
    Setting.set("pricing.models", { "claude-haiku-5-5" => { "input" => 1.0, "output" => 2.0 } })
    assert_equal BigDecimal("0.003"), price(model: "claude-haiku-5-5", input: 1000, output: 1000)
  end
end
