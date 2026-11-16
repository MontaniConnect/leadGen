require "test_helper"

class Scoring::SchemaTest < ActiveSupport::TestCase
  include ScoringTestHelper

  test "a valid output passes" do
    assert_empty Scoring::Schema.errors_for(VALID_OUTPUT)
  end

  test "range, count, type and missing-field violations are reported" do
    assert_not_empty Scoring::Schema.errors_for(VALID_OUTPUT.merge("staffing_score" => 11))
    assert_not_empty Scoring::Schema.errors_for(VALID_OUTPUT.merge("automation_score" => 0))
    four = Array.new(4) { { "signal" => "s", "source" => "x" } }
    assert_not_empty Scoring::Schema.errors_for(VALID_OUTPUT.merge("top_signals" => four))
    assert_not_empty Scoring::Schema.errors_for(VALID_OUTPUT.except("lead_with"))
    assert_not_empty Scoring::Schema.errors_for(VALID_OUTPUT.merge("extra" => 1))
    assert_not_empty Scoring::Schema.errors_for(VALID_OUTPUT.merge("disqualified" => "no"))
  end

  test "the API copy drops unsupported keywords but keeps the structure" do
    text = Scoring::Schema.for_api.to_json
    %w[minimum maximum maxItems maxLength].each { |keyword| assert_not_includes text, "\"#{keyword}\"" }
    assert_includes text, "additionalProperties"
    assert_includes text, "staffing_score"
  end
end
