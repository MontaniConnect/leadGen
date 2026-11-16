require "test_helper"

class Budget::RecordingTest < ActiveSupport::TestCase
  include DraftingTestHelper

  setup { @company = company_with_pages }

  test "a scoring evaluation stores its cost: 900 in, 150 out, 700 cached = $0.000172" do
    evaluation = Scoring::Recorder.new.call(@company, reply)
    assert_equal BigDecimal("0.000172"), evaluation.cost_usd
  end

  test "batch results are recorded at half price" do
    evaluation = Scoring::Recorder.new.call(@company, reply, batch: true)
    assert_equal BigDecimal("0.000086"), evaluation.cost_usd
  end

  test "cache writes are priced at the 1-hour rate" do
    evaluation = Scoring::Recorder.new.call(@company, reply(cache_read_tokens: 0, cache_write_tokens: 1000))
    # (900 * .10 + 150 * .50 + 1000 * .10 * 2.0) / 1e6
    assert_equal BigDecimal("0.000365"), evaluation.cost_usd
  end

  test "a call that failed before any reply costs nothing" do
    failure = Scoring::Recorder.new.record_failure(@company, "api error: timeout")
    assert_equal 0, failure.cost_usd
    assert_equal 0, failure.tokens_in.to_i
  end

  test "an unpriced model never loses a paid result: stored at $0 and reported" do
    Setting.set("models.scoring", "claude-mystery")
    reported = []
    subscriber = Class.new { define_method(:report) { |error, **| reported << error.class } }.new
    Rails.error.subscribe(subscriber)
    evaluation = Scoring::Recorder.new.call(@company, reply)

    assert_equal "ok", evaluation.status
    assert_equal 0, evaluation.cost_usd
    assert_includes reported, Budget::Pricing::UnknownModel
  ensure
    Rails.error.unsubscribe(subscriber)
  end

  test "a draft run stores its cost at the drafting model's price" do
    hot = hot_company(name: "Hot")
    run = Drafting::Recorder.new.call(hot, reply(drafts))
    assert_equal BigDecimal("0.00344"), run.cost_usd
  end

  test "ledger spent is the sum of scoring and drafting costs" do
    Scoring::Recorder.new.call(@company, reply)
    Drafting::Recorder.new.call(hot_company(name: "Hot"), reply(drafts))
    assert_equal BigDecimal("0.003612"), Budget::Ledger.new.spent
  end
end
