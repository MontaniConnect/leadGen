require "test_helper"

class Prefilter::EvaluatorTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 11, 16)

  RULES = Prefilter::Rules.new(
    min_employees: 10, max_employees: 200, countries: [ "United States", "USA" ],
    excluded_naics_prefixes: %w[5613 561422], excluded_keywords: %w[staffing bpo],
    excluded_keyword_fields: %w[keywords industry], boost_technologies: %w[AWS Salesforce],
    boost_keywords: %w[saas], intent_min_score: 50, why_now_funding_days: 90
  )

  def evaluate(**attrs)
    base = { name: "Co", employees: 50, country: "United States" }
    Prefilter::Evaluator.new(RULES, today: TODAY).call(Company.new(base.merge(attrs)))
  end

  test "a clean US company in range passes" do
    result = evaluate
    assert result.pass?
    assert_empty result.reasons
  end

  test "employee bounds are inclusive and unknown fails" do
    assert evaluate(employees: 10).pass?
    assert evaluate(employees: 200).pass?
    assert_equal [ "employees_below_min" ], evaluate(employees: 9).reasons
    assert_equal [ "employees_above_max" ], evaluate(employees: 201).reasons
    assert_equal [ "employees_unknown" ], evaluate(employees: nil).reasons
  end

  test "country accepts aliases case-insensitively and fails others" do
    assert evaluate(country: "usa").pass?
    assert_equal [ "country_not_allowed" ], evaluate(country: "Canada").reasons
    assert_equal [ "country_unknown" ], evaluate(country: "").reasons
  end

  test "excluded NAICS prefix matches any code in a list" do
    assert_equal [ "excluded_naics: 5613" ], evaluate(naics_codes: "541511, 561320").reasons
    assert_includes evaluate(naics_codes: "561422").reasons, "excluded_naics: 561422"
    assert evaluate(naics_codes: "541511").pass?
  end

  test "excluded keywords match whole words in keywords and industry" do
    assert_equal [ "excluded_keyword: staffing" ], evaluate(industry: "Staffing & Recruiting").reasons
    assert_equal [ "excluded_keyword: bpo" ], evaluate(keywords: "saas, BPO").reasons
    assert evaluate(keywords: "bpoint payments").pass?
  end

  test "all failing reasons are reported together" do
    result = evaluate(employees: 5, country: "France")
    assert_equal %w[employees_below_min country_not_allowed], result.reasons
  end

  test "boosts apply to passing companies" do
    result = evaluate(technologies: "AWS, Postgres", keywords: "SaaS", intent_score: 80,
                      last_raised_at: TODAY - 30)
    assert_equal [ "technology: AWS", "keyword: saas", "intent_score", "funding_within_90_days" ], result.boosts
    assert_equal 4, result.score
  end

  test "old or future funding and low intent do not boost" do
    assert_empty evaluate(last_raised_at: TODAY - 91, intent_score: 10).boosts
    assert_empty evaluate(last_raised_at: TODAY + 5).boosts
  end

  test "failing companies get no boosts" do
    assert_empty evaluate(employees: 1, technologies: "AWS").boosts
  end
end
