require "test_helper"

class Scoring::BatchTest < ActiveJob::TestCase
  include ScoringTestHelper

  setup do
    @a = company_with_pages(name: "Alpha")
    @b = company_with_pages(name: "Bravo")
    @c = company_with_pages(name: "Charlie")
  end

  test "submits companies in chunks with a custom id and identical params" do
    gateway = FakeGateway.new
    batches = Scoring::BatchSubmitter.new(gateway: gateway, batch_size: 2).call

    assert_equal [ 2, 1 ], batches.map(&:requests_count)
    assert_equal [ "company-#{@a.id}", "company-#{@b.id}" ], gateway.batches.first.map { |e| e[:custom_id] }
    assert_equal Scoring::RequestBuilder.new.call(@a.reload).except(:messages),
                 gateway.batches.first.first[:params].except(:messages)
    assert_equal %w[msgbatch_1 msgbatch_2], ScoringBatch.order(:id).pluck(:anthropic_batch_id)
  end

  test "an already-scored company is not submitted again" do
    Scoring::CompanyScorer.new(gateway: FakeGateway.new(replies: [ reply ])).call(@a)
    gateway = FakeGateway.new
    Scoring::BatchSubmitter.new(gateway: gateway).call
    assert_equal 2, gateway.batches.first.size
  end

  test "collector reports pending until the batch has ended" do
    batch = ScoringBatch.create!(anthropic_batch_id: "b1", company_ids: [ @a.id ])
    gateway = FakeGateway.new(batch_status: Scoring::BatchStatus.new("b1", false, 0, 0))
    assert_equal :pending, Scoring::BatchCollector.new(gateway: gateway).call(batch)
    assert_not batch.reload.collected?
  end

  test "collector stores successes, failures and errored entries independently" do
    batch = ScoringBatch.create!(anthropic_batch_id: "b1", company_ids: [ @a.id, @b.id, @c.id ])
    entries = [
      Scoring::BatchEntry.new("company-#{@a.id}", "succeeded", reply, nil),
      Scoring::BatchEntry.new("company-#{@b.id}", "succeeded", reply("garbage"), nil),
      Scoring::BatchEntry.new("company-#{@c.id}", "errored", nil, "overloaded"),
      Scoring::BatchEntry.new("company-999999", "expired", nil, "expired")
    ]
    gateway = FakeGateway.new(batch_status: Scoring::BatchStatus.new("b1", true, 1, 1), batch_entries: entries)

    assert_equal :collected, Scoring::BatchCollector.new(gateway: gateway).call(batch)

    assert_equal "Hot", @a.current_evaluation.tier
    assert_equal "failed", @b.evaluations.last.status
    assert_includes @c.evaluations.last.error, "batch errored: overloaded"
    assert_equal [ 1, 3 ], [ batch.reload.succeeded, batch.errored ]
    assert_equal [ @b, @c ].sort_by(&:id), Company.awaiting_evaluation.order(:id).to_a
  end

  test "a collected batch is not collected twice" do
    batch = ScoringBatch.create!(anthropic_batch_id: "b1", collected_at: Time.current)
    assert_equal :collected, Scoring::BatchCollector.new(gateway: FakeGateway.new).call(batch)
  end

  test "the job reschedules itself while the batch is pending" do
    batch = ScoringBatch.create!(anthropic_batch_id: "b1")
    gateway = FakeGateway.new(batch_status: Scoring::BatchStatus.new("b1", false, 0, 0))
    assert_enqueued_with(job: CollectScoringBatchJob, args: [ batch.id ]) do
      CollectScoringBatchJob.perform_now(batch.id, gateway: gateway)
    end
  end
end
