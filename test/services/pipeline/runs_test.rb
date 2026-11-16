require "test_helper"

class Pipeline::RunsTest < ActiveSupport::TestCase
  include DraftingTestHelper

  # A reply whose input is so large that each call costs about $0.50 on Haiku.
  def pricey(output = VALID_OUTPUT) = reply(output, input_tokens: 5_000_000)

  def scoring_run(gateway, **options)
    out = StringIO.new
    [ Pipeline::ScoringRun.new(gateway: gateway, out: out, **options).call, out.string ]
  end

  test "a scoring run tracks every call: tokens, cost and a printed summary" do
    3.times { |i| company_with_pages(name: "Co#{i}") }
    run, output = scoring_run(FakeGateway.new(replies: [ reply, reply, reply ]))

    assert_equal "complete", run.status
    totals = run.totals
    assert_equal [ 3, 0, 2700, 450 ], totals.values_at(:calls, :failed, :input_tokens, :output_tokens)
    assert_equal BigDecimal("0.000516"), totals[:cost_usd] # 3 x $0.000172
    assert_equal run, Evaluation.last.pipeline_run
    assert_includes output, "Run ##{run.id} (score): complete. 3 calls (0 failed)"
    assert_includes output, "cost $0.0005"
  end

  test "a failed reply still costs money and shows in the totals" do
    company_with_pages(name: "Odd")
    run, = scoring_run(FakeGateway.new(replies: [ reply("not json") ]))

    assert_equal [ 1, 1 ], run.totals.values_at(:calls, :failed)
    assert_equal BigDecimal("0.000172"), run.totals[:cost_usd]
    assert_equal BigDecimal("0.000172"), Budget::Ledger.new.spent
  end

  test "the run halts as soon as the next call could pass the cap, and no further calls are made" do
    5.times { |i| company_with_pages(name: "Co#{i}") }
    Setting.set("budget.spending_cap_usd", 0.6)
    gateway = FakeGateway.new(replies: Array.new(5) { pricey })
    run, output = scoring_run(gateway)

    assert_equal "halted", run.status
    assert_equal 2, gateway.requests.size, "calls 1 and 2 fit; the third would exceed $0.60"
    assert_equal 2, Evaluation.count
    assert_match(/Spending cap reached/, run.halted_reason)
    assert_includes output, "Spending cap reached"
    assert_equal 3, Company.awaiting_evaluation.count, "the rest stay queued for after the cap is raised"
  end

  test "with no cap set nothing is sent at all" do
    company_with_pages(name: "Co")
    Setting.reset("budget.spending_cap_usd")
    gateway = FakeGateway.new(replies: [ reply ])
    run, = scoring_run(gateway)

    assert_equal "halted", run.status
    assert_empty gateway.requests
    assert_equal 0, Evaluation.count
    assert_includes run.halted_reason, "No spending cap is set"
  end

  test "an unpriced model stops the run as a failure instead of spending blind" do
    company_with_pages(name: "Co")
    Setting.set("models.scoring", "claude-mystery")
    gateway = FakeGateway.new(replies: [ reply ])

    assert_raises(Budget::Pricing::UnknownModel) { scoring_run(gateway) }
    assert_empty gateway.requests
    assert_equal "failed", PipelineRun.last.status
  end

  test "raising the cap lets a halted run continue where it stopped" do
    3.times { |i| company_with_pages(name: "Co#{i}") }
    Setting.set("budget.spending_cap_usd", 0.6)
    scoring_run(FakeGateway.new(replies: Array.new(3) { pricey }))
    assert_equal 1, Company.awaiting_evaluation.count

    Setting.set("budget.spending_cap_usd", 100)
    run, = scoring_run(FakeGateway.new(replies: [ reply ]))
    assert_equal "complete", run.status
    assert_equal 0, Company.awaiting_evaluation.count
  end

  test "the limit and scope narrow which companies are scored" do
    a = company_with_pages(name: "A")
    company_with_pages(name: "B")
    company_with_pages(name: "C")
    gateway = FakeGateway.new(replies: [ reply ])
    scoring_run(gateway, scope: Company.where(id: a.id))
    assert_equal 1, gateway.requests.size

    gateway = FakeGateway.new(replies: [ reply ])
    scoring_run(gateway, limit: 1)
    assert_equal 1, gateway.requests.size
  end

  test "a drafting run tracks tokens and cost at Sonnet prices" do
    hot_company(name: "HotOne")
    out = StringIO.new
    run = Pipeline::DraftingRun.new(gateway: FakeGateway.new(replies: [ reply(drafts) ]), out: out).call

    assert_equal "complete", run.status
    assert_equal BigDecimal("0.00344"), run.totals[:cost_usd] # (900*2 + 150*10 + 700*2*0.1) / 1e6
    assert_includes out.string, "HotOne: curious_question, low_pressure_offer"
    assert_equal run, DraftRun.last.pipeline_run
  end

  test "a drafting run halts at the cap too, including between retry attempts" do
    hot_company(name: "HotOne")
    hot_company(name: "HotTwo")
    Setting.set("budget.spending_cap_usd", 0.2)
    bad = reply(drafts(curious: "#{'word ' * 55}?"), input_tokens: 40_000_000) # invalid and ~$80
    gateway = FakeGateway.new(replies: [ bad, bad, bad, bad ])
    run = Pipeline::DraftingRun.new(gateway: gateway, out: StringIO.new).call

    assert_equal "halted", run.status
    assert_equal 1, gateway.requests.size, "the first failed attempt spent past the cap, so no retry and no second company"
    assert_equal 0, Message.count
  end

  test "PipelineRun.track marks unexpected errors as failed and re-raises" do
    assert_raises(RuntimeError) { PipelineRun.track("score") { raise "boom" } }
    assert_equal [ "failed", "RuntimeError: boom" ], PipelineRun.last.slice(:status, :halted_reason).values
  end

  test "PipelineRun.track rejects an unknown kind" do
    assert_raises(ActiveRecord::RecordInvalid) { PipelineRun.track("mystery") { nil } }
  end
end
