require "test_helper"

class DashboardPipelineTest < ActionDispatch::IntegrationTest
  include DraftingTestHelper

  setup { Scoring::ApiKey.lookup = -> { "sk-test" } }
  teardown { Scoring::ApiKey.lookup = nil }

  def steps_text = css_select(".steps > li").map { |li| li.text.squish }

  test "the panel lists the steps with real counts" do
    Company.create!(name: "Unfetched", domain: "u.com", prefilter_status: "pass")
    company_with_pages(name: "Fetched")
    hot_company(name: "HotOne")
    get dashboard_path

    assert_select "#pipeline-heading", text: "Pipeline"
    steps = steps_text
    assert_match(/1\. Passed the filters: 3 companies/, steps[0])
    assert_match(/2\. Pages fetched: 2 of 3/, steps[1])
    assert_match(/4\. Scored: Hot 1 · Warm 0 · Cold 0/, steps[3])
    assert_match(/5\. Messages drafted \(Hot and Warm\): 0 companies/, steps[4])
  end

  test "the Score button shows what it will cost and asks for confirmation before spending" do
    company_with_pages(name: "Alpha")
    company_with_pages(name: "Bravo")
    get dashboard_path

    assert_select "form[action='#{pipeline_score_path}']" do |forms|
      confirm = forms.first["data-turbo-confirm"]
      assert_match(/Score 2 companies\? This calls the Anthropic API: expected \$\d\.\d{4}, never more than \$\d\.\d{4}, and it stops by itself at your spending cap/, confirm)
    end
    assert_select "button", text: /Score 2 companies \(about \$\d\.\d{4}, at most \$\d\.\d{4}\)/
  end

  test "with no cap, there is no Score button, only the reason" do
    company_with_pages(name: "Alpha")
    Setting.reset("budget.spending_cap_usd")
    get dashboard_path

    assert_select "form[action='#{pipeline_score_path}']", count: 0
    assert_select ".hint", text: /No spending cap is set/
  end

  test "with no API key, there is no Score button either" do
    company_with_pages(name: "Alpha")
    Scoring::ApiKey.lookup = -> { nil }
    get dashboard_path
    assert_select ".hint", text: /API key is not set/
    assert_select "form[action='#{pipeline_score_path}']", count: 0
  end

  test "while a run is active the page refreshes itself and offers no second Score button" do
    company_with_pages(name: "Alpha")
    PipelineRun.start!("score")
    get dashboard_path

    assert_select "meta[http-equiv=refresh][content='5']"
    assert_select "form[action='#{pipeline_score_path}']", count: 0
    assert_select ".hint", text: /already in progress/
  end

  test "an idle dashboard does not refresh itself" do
    get dashboard_path
    assert_select "meta[http-equiv=refresh]", count: 0
  end

  test "the last run's tokens and cost are shown" do
    company = company_with_pages(name: "Alpha")
    run = PipelineRun.create!(kind: "score", started_at: Time.current, status: "complete")
    Scoring::Recorder.new.call(company, reply, run: run)
    get dashboard_path

    assert_select ".hint", text: /Run ##{run.id} \(score\): complete\. 1 calls \(0 failed\), 900 input \+ 150 output tokens.*cost \$0\.0002/
  end

  test "the Draft button appears only when Hot or Warm leads are waiting for messages" do
    get dashboard_path
    assert_select "form[action='#{pipeline_draft_path}']", count: 0
    assert_select ".hint", text: /Nothing to draft right now/

    hot_company(name: "HotOne")
    get dashboard_path
    assert_select "button", text: /Draft messages for 1 lead \(about/
  end

  test "each company row shows its tier and scores once scored" do
    Scoring::Recorder.new.call(company_with_pages(name: "Alpha"), reply)
    get dashboard_path
    assert_select "th", text: "Scored"
    assert_select "td", text: "Hot 8/6, Medium"
  end
end
