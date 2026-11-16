require "test_helper"

class Budget::DryRunTest < ActiveSupport::TestCase
  include DraftingTestHelper

  # Counts a fixed number of tokens for every request, and 1,000 for the shared instructions.
  FixedCounter = Struct.new(:tokens) do
    def count(_request) = tokens
    def count_text(_text) = 1000
  end

  setup do
    3.times { |i| company_with_pages(name: "Pending#{i}") }       # fetched, awaiting scoring
    Company.create!(name: "Unfetched", prefilter_status: "pass")  # passed, no pages: projected
    Company.create!(name: "Failed", prefilter_status: "fail")     # never counted
    hot_company(name: "HotLead")                                  # scored Hot, awaiting drafts
  end

  def run_dry(counter: FixedCounter.new(3000), **options)
    Budget::DryRun.new(counter: counter, prefix_estimator: FixedCounter.new(3000), **options.slice(:sample_size))
                  .call(**options.except(:sample_size))
  end

  test "counts real and projected companies per stage" do
    scoring, drafting = run_dry.stages

    assert_equal [ 4, 1 ], [ scoring.companies, scoring.projected ]
    assert_equal 3 * 3000 + 6000, scoring.input_tokens
    assert_equal [ 4, 3 ], [ drafting.companies, drafting.projected ] # 1 real Hot + ceil(4 * 0.6) projected
    assert_equal 3000 + 3 * 5000, drafting.input_tokens
  end

  test "scoring cost matches the hand calculation" do
    scoring = run_dry.stages.first
    # expected: (11,000 in * .10 + 1,800 out * .50 + 3,000 cache reads * .01 + 1,000 cache write * .20) / 1e6
    assert_equal BigDecimal("0.00223"), scoring.expected_cost
    # worst: (15,000 in * .10 + 12,000 out * .50) / 1e6, because every reply may fill max_tokens (3,000 x 4 companies)
    assert_equal BigDecimal("0.0075"), scoring.worst_case_cost
  end

  test "drafting cost matches the hand calculation" do
    drafting = run_dry.stages.last
    # 4 leads (1 real + 3 projected); expected:
    # (14,000 in * 2 + 3,600 out * 10 + 3,000 cache reads * .2 + 1,000 write * 4) / 1e6
    assert_equal BigDecimal("0.0686"), drafting.expected_cost
    # worst: (18,000 in * 2 + 8,000 out * 10) / 1e6
    assert_equal BigDecimal("0.116"), drafting.worst_case_cost
  end

  test "totals add up and batch pricing halves everything" do
    result = run_dry
    assert_equal BigDecimal("0.07083"), result.expected_cost
    assert_equal BigDecimal("0.1235"), result.worst_case_cost
    assert_equal BigDecimal("0.035415"), run_dry(batch: true).expected_cost
  end

  test "worst case versus the cap decides whether it fits" do
    Setting.set("budget.spending_cap_usd", 1)
    assert run_dry.fits?
    Setting.set("budget.spending_cap_usd", 0.1)
    assert_not run_dry.fits?
    Setting.reset("budget.spending_cap_usd")
    assert_not run_dry.fits?, "no cap means nothing fits"
  end

  test "spend already committed reduces what remains" do
    Setting.set("budget.spending_cap_usd", 0.13)
    assert run_dry.fits?
    ScoringBatch.create!(anthropic_batch_id: "b1", reserved_usd: 0.02)
    assert_not run_dry.fits?
  end

  test "limit caps the companies counted, real ones first" do
    scoring = run_dry(limit: 2).stages.first
    assert_equal [ 2, 0 ], [ scoring.companies, scoring.projected ]
  end

  test "scope restricts the estimate to a set of companies (the pilot)" do
    scoring = run_dry(scope: Company.where(name: %w[Pending0 Unfetched])).stages.first
    assert_equal [ 2, 1 ], [ scoring.companies, scoring.projected ]
  end

  test "exact counting samples a few requests and scales the average up" do
    gateway = FakeGateway.new
    gateway.token_count_value = 4000
    result = run_dry(counter: Budget::ExactTokenCounter.new(gateway: gateway), sample_size: 2)

    assert_equal 4000 * 3 + 6000, result.stages.first.input_tokens # 2 counted, scaled to 3, plus projected
    assert_equal 3, gateway.token_counts.size # 2 for scoring + 1 for the single Hot lead
    assert_match(/exact/, result.counting)
  end

  test "nothing to do costs nothing" do
    Company.destroy_all
    result = run_dry
    assert_equal 0, result.expected_cost
    assert_equal 0, result.worst_case_cost
  end

  test "the dry run makes no network calls and writes nothing" do
    assert_no_difference [ "Evaluation.count", "DraftRun.count", "PipelineRun.count", "ScoringBatch.count" ] do
      Budget::DryRun.new.call # real estimator, no gateway at all
    end
  end

  test "the report shows stages, totals, the cap verdict and projections" do
    Setting.set("budget.spending_cap_usd", 1)
    text = Budget::DryRunReport.new(run_dry).to_s

    assert_includes text, "DRY RUN: no paid API calls were made."
    assert_includes text, "4 (1 projected)"
    assert_includes text, "claude-haiku-5-5"
    assert_includes text, "$0.0708"
    assert_includes text, "Worst case fits within the cap: YES"

    Setting.reset("budget.spending_cap_usd")
    assert_includes Budget::DryRunReport.new(run_dry).to_s, "NOT SET"
  end
end
