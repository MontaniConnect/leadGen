require "test_helper"

class Scoring::CompanyScorerTest < ActiveSupport::TestCase
  include ScoringTestHelper

  setup { @company = company_with_pages }

  def scorer(gateway) = Scoring::CompanyScorer.new(gateway: gateway)

  test "scores a company with one call" do
    gateway = FakeGateway.new(replies: [ reply ])
    evaluation = scorer(gateway).call(@company)

    assert_equal "Hot", evaluation.tier
    assert_equal 1, gateway.requests.size
    assert_equal evaluation, @company.reload.current_evaluation
  end

  test "an already-scored company is skipped without any API call" do
    scorer(FakeGateway.new(replies: [ reply ])).call(@company)
    gateway = FakeGateway.new
    assert_nil scorer(gateway).call(@company)
    assert_empty gateway.requests
  end

  test "force re-scores and the newest ok evaluation becomes current" do
    scorer(FakeGateway.new(replies: [ reply ])).call(@company)
    second = scorer(FakeGateway.new(replies: [ reply(VALID_OUTPUT.merge("staffing_score" => 3, "automation_score" => 3)) ]))
              .call(@company, force: true)

    assert_equal "Cold", second.tier
    assert_equal second, @company.current_evaluation
    assert_equal 2, @company.evaluations.count
  end

  test "an API error is recorded as a failure and the company can be retried alone" do
    error = Anthropic::Errors::APIConnectionError.new(url: URI("https://api.anthropic.com"), message: "boom")
    failed = scorer(FakeGateway.new(replies: [ error ])).call(@company)

    assert_equal "failed", failed.status
    assert_includes failed.error, "APIConnectionError"
    assert_includes Company.awaiting_evaluation, @company

    retried = scorer(FakeGateway.new(replies: [ reply ])).call(@company)
    assert_equal "ok", retried.status
    assert_not_includes Company.awaiting_evaluation, @company
  end

  test "awaiting_evaluation needs a pass, fetched pages and no ok evaluation" do
    unfetched = Company.create!(name: "Unfetched", prefilter_status: "pass")
    failed_prefilter = company_with_pages(name: "Nope")
    failed_prefilter.update!(prefilter_status: "fail")

    assert_equal [ @company ], Company.awaiting_evaluation.to_a
    assert_not_includes Company.awaiting_evaluation, unfetched
  end
end
