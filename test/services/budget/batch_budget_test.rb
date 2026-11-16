require "test_helper"

class Budget::BatchBudgetTest < ActiveJob::TestCase
  include ScoringTestHelper

  setup do
    3.times { |i| company_with_pages(name: "Co#{i}") }
  end

  def submit(gateway, **options) = Scoring::BatchSubmitter.new(gateway: gateway, **options).call

  test "submitting reserves the batch's worst case at half price against the cap" do
    batches = submit(FakeGateway.new)

    assert_equal 1, batches.size
    assert_operator batches.first.reserved_usd, :>, 0
    assert_equal batches.first.reserved_usd, Budget::Ledger.new.reserved
    assert_equal batches.first.reserved_usd, Budget::Ledger.new.committed
  end

  test "a batch that cannot fit under the cap is refused before anything is sent" do
    Setting.set("budget.spending_cap_usd", 0.001)
    gateway = FakeGateway.new

    assert_raises(Budget::Guard::CapReached) { submit(gateway) }
    assert_empty gateway.batches
    assert_equal 0, ScoringBatch.count
  end

  test "with no cap, nothing is submitted" do
    Setting.reset("budget.spending_cap_usd")
    gateway = FakeGateway.new
    assert_raises(Budget::Guard::NoCapSet) { submit(gateway) }
    assert_empty gateway.batches
  end

  test "the reservation is released when the batch is collected and real cost is recorded" do
    run = PipelineRun.create!(kind: "score_batch", started_at: Time.current)
    batch = submit(FakeGateway.new, guard: Budget::Guard.new).first
    batch.update!(pipeline_run: run)
    company = Company.find(batch.company_ids.first)
    entries = [ Scoring::BatchEntry.new("company-#{company.id}", "succeeded", reply, nil) ]
    gateway = FakeGateway.new(batch_status: Scoring::BatchStatus.new("b", true, 1, 0), batch_entries: entries)

    assert_operator Budget::Ledger.new.reserved, :>, 0
    Scoring::BatchCollector.new(gateway: gateway).call(batch)

    assert_equal 0, Budget::Ledger.new.reserved
    evaluation = company.evaluations.last
    assert_equal BigDecimal("0.000086"), evaluation.cost_usd, "batch results are half price"
    assert_equal run, evaluation.pipeline_run
    assert_equal "complete", run.reload.status
    assert_equal BigDecimal("0.000086"), Budget::Ledger.new.spent
  end

  test "BatchSubmission reports a halt on the run instead of raising" do
    Setting.set("budget.spending_cap_usd", 0.001)
    out = StringIO.new
    run = Pipeline::BatchSubmission.new(gateway: FakeGateway.new, out: out).call

    assert_equal "halted", run.status
    assert_includes out.string, "Spending cap reached"
  end

  test "BatchSubmission prints what it reserved, and an empty queue is a clean no-op" do
    out = StringIO.new
    run = Pipeline::BatchSubmission.new(gateway: FakeGateway.new, out: out).call
    assert_equal "running", run.status, "stays running until its batches are collected"
    assert_match(/submitted msgbatch_1: 3 companies, reserved \$0\.\d{4}/, out.string)

    Company.awaiting_evaluation.destroy_all
    out = StringIO.new
    empty = Pipeline::BatchSubmission.new(gateway: FakeGateway.new, out: out).call
    assert_equal "complete", empty.status
    assert_includes out.string, "nothing to score"
  end
end
