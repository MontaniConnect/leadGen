require "test_helper"

class PipelineControllerTest < ActionDispatch::IntegrationTest
  include DraftingTestHelper

  setup { Scoring::ApiKey.lookup = -> { "sk-test" } }
  teardown { Scoring::ApiKey.lookup = nil }

  # --- scoring ---

  test "Score starts a tracked run and hands the work to a background job" do
    company_with_pages(name: "Alpha")
    assert_enqueued_jobs 1, only: ScoringRunJob do
      post pipeline_score_path
    end

    run = PipelineRun.last
    assert_equal [ "score", "running" ], [ run.kind, run.status ]
    assert_enqueued_with(job: ScoringRunJob, args: [ run.id ])
    assert_redirected_to dashboard_path
    assert_match(/Scoring started/, flash[:notice])
  end

  test "a second click while a run is active is refused: no second run, no second job" do
    company_with_pages(name: "Alpha")
    post pipeline_score_path
    assert_no_enqueued_jobs only: ScoringRunJob do
      post pipeline_score_path
    end
    assert_match(/already in progress/, flash[:alert])
    assert_equal 1, PipelineRun.where(kind: "score").count
  end

  test "the database itself refuses two active runs of the same kind, so even a race cannot double-spend" do
    PipelineRun.start!("score")
    assert_raises(ActiveRecord::RecordNotUnique) { PipelineRun.start!("score") }
    assert_nothing_raised { PipelineRun.start!("draft") }
    assert_nothing_raised { 3.times { PipelineRun.create!(kind: "score_batch", started_at: Time.current) } }
  end

  test "a click that loses the race is reported cleanly, not as an error page" do
    company_with_pages(name: "Alpha")
    PipelineRun.create!(kind: "score", started_at: Time.current)
    Pipeline::Readiness.class_eval { alias_method :__real_problem, :problem; define_method(:problem) { nil } }
    begin
      post pipeline_score_path
      assert_match(/already in progress/, flash[:alert])
      assert_equal 1, PipelineRun.where(kind: "score").count
    ensure
      Pipeline::Readiness.class_eval { alias_method :problem, :__real_problem; remove_method :__real_problem }
    end
  end

  test "a run whose process died is cleared after 30 minutes instead of blocking forever" do
    company_with_pages(name: "Alpha")
    stuck = PipelineRun.create!(kind: "score", started_at: 31.minutes.ago)
    post pipeline_score_path

    assert_equal "failed", stuck.reload.status
    assert_match(/Stopped responding/, stuck.halted_reason)
    assert_equal "running", PipelineRun.last.status
    assert_match(/Scoring started/, flash[:notice])
  end

  test "no spending cap: refused, with the reason, and nothing is started" do
    company_with_pages(name: "Alpha")
    Setting.reset("budget.spending_cap_usd")
    assert_no_enqueued_jobs only: ScoringRunJob do
      post pipeline_score_path
    end
    assert_match(/No spending cap is set/, flash[:alert])
    assert_equal 0, PipelineRun.count
  end

  test "no API key: refused, with the reason" do
    company_with_pages(name: "Alpha")
    Scoring::ApiKey.lookup = -> { nil }
    post pipeline_score_path
    assert_match(/API key is not set/, flash[:alert])
    assert_equal 0, PipelineRun.count
  end

  test "nothing to score: refused" do
    post pipeline_score_path
    assert_equal "Nothing to score right now.", flash[:alert]
    assert_equal 0, PipelineRun.count
  end

  # --- drafting ---

  test "Draft starts a tracked drafting run for Hot leads" do
    hot_company(name: "HotOne")
    assert_enqueued_jobs 1, only: DraftingRunJob do
      post pipeline_draft_path
    end
    assert_equal [ "draft", "running" ], PipelineRun.last.slice(:kind, :status).values
    assert_match(/Drafting started/, flash[:notice])
  end

  test "Draft is refused when there are no Hot leads to draft for" do
    company_with_pages(name: "Alpha")
    post pipeline_draft_path
    assert_equal "Nothing to draft right now.", flash[:alert]
  end

  test "scoring and drafting can run at the same time, but never two of the same kind" do
    company_with_pages(name: "Alpha")
    hot_company(name: "HotOne")
    post pipeline_score_path
    post pipeline_draft_path
    assert_equal %w[draft score], PipelineRun.where(status: "running").pluck(:kind).sort
  end

  # --- fetching (free) ---

  test "Fetch queues only the passed companies that have a website and no pages yet" do
    wanted = Company.create!(name: "Wanted", domain: "wanted.com", prefilter_status: "pass")
    fetched = Company.create!(name: "Fetched", domain: "fetched.com", prefilter_status: "pass")
    fetched.pages.create!(kind: "home", status: "ok", url: "https://fetched.com/", text: "x")
    Company.create!(name: "NoSite", prefilter_status: "pass")
    Company.create!(name: "Failed", domain: "failed.com", prefilter_status: "fail")

    assert_enqueued_jobs 1, only: FetchCompanyPagesJob do
      post pipeline_fetch_path
    end
    assert_enqueued_with(job: FetchCompanyPagesJob, args: [ wanted.id ])
    assert_match(/Fetching pages for 1 company/, flash[:notice])
  end

  test "Fetch with nothing to do says so" do
    post pipeline_fetch_path
    assert_match(/Nothing to fetch/, flash[:notice])
  end
end
