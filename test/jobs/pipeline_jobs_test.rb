require "test_helper"

class PipelineJobsTest < ActiveJob::TestCase
  include DraftingTestHelper

  test "the scoring job does the work inside the run it was given and completes it" do
    company_with_pages(name: "Alpha")
    run = PipelineRun.start!("score")
    ScoringRunJob.perform_now(run.id, gateway: FakeGateway.new(replies: [ reply ]))

    run.reload
    assert_equal "complete", run.status
    assert_equal 1, run.evaluations.count
    assert_not_nil run.finished_at
  end

  test "the scoring job stops at the spending cap and the run says why" do
    3.times { |i| company_with_pages(name: "Co#{i}") } # each call costs ~$0.50, so the third cannot fit under $0.60
    Setting.set("budget.spending_cap_usd", 0.6)
    run = PipelineRun.start!("score")
    ScoringRunJob.perform_now(run.id, gateway: FakeGateway.new(replies: Array.new(3) { reply(input_tokens: 5_000_000) }))

    assert_equal "halted", run.reload.status
    assert_match(/Spending cap reached/, run.halted_reason)
  end

  test "an unexpected error marks the run failed (so it cannot block future runs) and is not hidden" do
    company_with_pages(name: "Alpha")
    run = PipelineRun.start!("score")
    boom = Object.new
    boom.define_singleton_method(:message) { |_request, **| raise "network exploded" }

    assert_raises(RuntimeError) { ScoringRunJob.perform_now(run.id, gateway: boom) }
    assert_equal "failed", run.reload.status
    assert_match(/network exploded/, run.halted_reason)
    assert_nothing_raised { PipelineRun.start!("score") }
  end

  test "the drafting job drafts Hot leads inside its run" do
    hot_company(name: "HotOne")
    run = PipelineRun.start!("draft")
    DraftingRunJob.perform_now(run.id, gateway: FakeGateway.new(replies: [ reply(drafts) ]))

    assert_equal "complete", run.reload.status
    assert_equal 1, run.draft_runs.count
    assert_equal 2, Message.count
  end

  test "a run deleted before its job starts is ignored" do
    assert_raises(ActiveRecord::RecordNotFound) { ScoringRunJob.perform_now(0) }
  end

  test "stale runs are cleared and fresh ones are left alone" do
    stale = PipelineRun.create!(kind: "draft", started_at: 40.minutes.ago)
    fresh = PipelineRun.create!(kind: "score", started_at: 5.minutes.ago)
    PipelineRun.expire_stale!
    assert_equal [ "failed", "running" ], [ stale.reload.status, fresh.reload.status ]
    assert PipelineRun.active("score").exists?
    assert_not PipelineRun.active("draft").exists?
  end
end
