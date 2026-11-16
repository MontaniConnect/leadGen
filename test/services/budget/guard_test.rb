require "test_helper"

class Budget::GuardTest < ActiveSupport::TestCase
  include LeadsTestHelper

  # Worst case for this request on Haiku: 202 input tokens (606 chars / 3) + 1,000 max output
  # = (202 * 0.10 + 1000 * 0.50) / 1e6 = $0.0005202
  REQUEST = {
    model: "claude-haiku-5-5", max_tokens: 1000, system_: [ { type: "text", text: "x" * 300 } ],
    messages: [ { role: "user", content: "y" * 300 } ]
  }.freeze

  def guard = Budget::Guard.new

  test "the worst case is all input at full price plus a reply that fills max_tokens" do
    assert_equal BigDecimal("0.0005202"), guard.worst_case(REQUEST)
    assert_equal BigDecimal("0.0002601"), guard.worst_case(REQUEST, batch: true)
  end

  test "a call that fits under the cap is allowed" do
    Setting.set("budget.spending_cap_usd", 0.0006)
    assert_equal BigDecimal("0.0005202"), guard.authorize!(REQUEST)
  end

  test "a call that could push spend past the cap is refused, with the numbers in the message" do
    Setting.set("budget.spending_cap_usd", 0.0005)
    error = assert_raises(Budget::Guard::CapReached) { guard.authorize!(REQUEST) }
    assert_match(/Spending cap reached/, error.message)
    assert_match(/cap is \$0\.0005\./, error.message)
  end

  test "money already spent counts against the cap" do
    Setting.set("budget.spending_cap_usd", 0.001)
    guard.authorize!(REQUEST)
    lead(name: "Spent").evaluations.first.update!(cost_usd: 0.0005)
    assert_raises(Budget::Guard::CapReached) { guard.authorize!(REQUEST) }
  end

  test "batches not yet collected reserve their worst case, collected ones do not" do
    Setting.set("budget.spending_cap_usd", 0.001)
    pending = ScoringBatch.create!(anthropic_batch_id: "b1", reserved_usd: 0.0006)
    assert_raises(Budget::Guard::CapReached) { guard.authorize!(REQUEST) }

    pending.update!(collected_at: Time.current)
    assert_nothing_raised { guard.authorize!(REQUEST) }
  end

  test "with no cap set it fails closed" do
    Setting.reset("budget.spending_cap_usd")
    error = assert_raises(Budget::Guard::NoCapSet) { guard.authorize!(REQUEST) }
    assert_includes error.message, "budget:cap"
    assert_kind_of Budget::Guard::CapReached, error
  end

  test "an unpriced model is blocked too" do
    assert_raises(Budget::Pricing::UnknownModel) { guard.authorize!(REQUEST.merge(model: "claude-mystery")) }
  end

  test "a batch is authorized as a whole at half price and returns what to reserve" do
    Setting.set("budget.spending_cap_usd", 0.001)
    reserved = guard.authorize_batch!([ REQUEST, REQUEST ])
    assert_equal BigDecimal("0.0005202"), reserved

    Setting.set("budget.spending_cap_usd", 0.0005)
    assert_raises(Budget::Guard::CapReached) { guard.authorize_batch!([ REQUEST, REQUEST ]) }
  end

  test "Cap.set! accepts dollar amounts and rejects nonsense" do
    assert_equal 25.0, Budget::Cap.set!("$25")
    assert_equal 12.5, Budget::Cap.set!("12.50")
    assert_equal 1234.0, Budget::Cap.set!("1,234")
    [ "abc", "", "0", "-5", "100001" ].each do |bad|
      assert_raises(Budget::Cap::Invalid, "#{bad.inspect} should be rejected") { Budget::Cap.set!(bad) }
    end
    assert_equal 1234.0, Setting.get("budget.spending_cap_usd"), "a rejected value must not change the cap"
  end

  test "the shipped default has no cap" do
    Setting.reset("budget.spending_cap_usd")
    assert_nil Budget::Ledger.new.cap
  end
end
