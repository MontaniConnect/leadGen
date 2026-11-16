require "test_helper"

class Scoring::RecorderTest < ActiveSupport::TestCase
  include ScoringTestHelper

  setup { @company = company_with_pages }

  test "stores an ok evaluation with computed tier, confidence and tokens" do
    evaluation = Scoring::Recorder.new.call(@company, reply)

    assert_equal "ok", evaluation.status
    assert_equal [ 8, 6 ], [ evaluation.staffing_score, evaluation.automation_score ]
    assert_equal "Medium", evaluation.confidence # 3 ok pages + apollo description = 4 sources
    assert_equal "Hot", evaluation.tier
    assert_equal [ 900, 150, 700 ], [ evaluation.tokens_in, evaluation.tokens_out, evaluation.cache_read_tokens ]
    assert_equal "claude-haiku-5-5", evaluation.model
    assert_equal "v1", evaluation.prompt_version
    assert_equal "Hiring AWS engineers", evaluation.signals.first["signal"]
    assert_equal VALID_OUTPUT, evaluation.raw
  end

  test "disqualified companies are cold regardless of scores" do
    evaluation = Scoring::Recorder.new.call(@company, reply(VALID_OUTPUT.merge("disqualified" => true)))
    assert_equal "Cold", evaluation.tier
    assert evaluation.disqualified
  end

  test "low confidence turns a 7+ into Warm" do
    thin = Company.create!(name: "Thin", prefilter_status: "pass")
    assert_equal "Warm", Scoring::Recorder.new.call(thin, reply).tier
  end

  test "schema violations, bad JSON, truncation and refusals become failed evaluations with tokens kept" do
    {
      "schema" => reply(VALID_OUTPUT.merge("staffing_score" => 99)),
      "invalid JSON" => reply("not json"),
      "truncated" => reply("{}", stop_reason: "max_tokens"),
      "refusal (cyber)" => reply("", stop_reason: "refusal", refusal_category: "cyber")
    }.each do |expected, bad_reply|
      evaluation = Scoring::Recorder.new.call(@company, bad_reply)
      assert_equal "failed", evaluation.status
      assert_includes evaluation.error, expected
      assert_equal 900, evaluation.tokens_in
    end
    assert_nil @company.current_evaluation
  end
end
