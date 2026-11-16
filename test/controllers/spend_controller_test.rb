require "test_helper"

class SpendControllerTest < ActionDispatch::IntegrationTest
  include DraftingTestHelper

  test "shows spent, reserved, cap and remaining" do
    Setting.set("budget.spending_cap_usd", 10)
    company_with_pages.evaluations.create!(status: "ok", tier: "Cold", confidence: "Low", staffing_score: 1, automation_score: 1, cost_usd: 1.5)
    ScoringBatch.create!(anthropic_batch_id: "b1", reserved_usd: 0.25)
    get spend_path

    assert_response :success
    assert_select ".score-card", text: /Spent\s*\$1\.50/
    assert_select ".score-card", text: /Reserved\s*\$0\.2500/
    assert_select ".score-card", text: /Cap\s*\$10\.00/
    assert_select ".score-card", text: /Remaining\s*\$8\.25/
    assert_select ".flash.alert", count: 0
  end

  test "warns loudly when no cap is set" do
    Setting.reset("budget.spending_cap_usd")
    get spend_path
    assert_select ".flash.alert", text: /No spending cap is set/
    assert_select ".score-card", text: /Cap\s*Not set/
  end

  test "lists usage by model and runs with totals and halt reasons" do
    company = company_with_pages
    run = PipelineRun.create!(kind: "score", started_at: Time.current, status: "halted", halted_reason: "Spending cap reached: test")
    Scoring::Recorder.new.call(company, reply, run: run)
    hot = hot_company(name: "Hot")
    Drafting::Recorder.new.call(hot, reply(drafts))
    get spend_path

    assert_select "#models-heading + table td", text: "claude-haiku-5-5"
    assert_select "#models-heading + table td", text: "claude-sonnet-5-5"
    assert_select "#models-heading + table td", text: "$0.0034"
    assert_select "#runs-heading + table td", text: "Halted"
    assert_select "#runs-heading + table td", text: "Spending cap reached: test"
    assert_select "#runs-heading + table td", text: /900/
  end

  test "the cap can be changed from the page, and bad input is refused with a message" do
    patch cap_spend_path, params: { amount: "$40" }
    assert_redirected_to spend_path
    assert_equal 40.0, Setting.get("budget.spending_cap_usd")

    patch cap_spend_path, params: { amount: "lots" }
    assert_redirected_to spend_path
    assert_match(/not a dollar amount/, flash[:alert])
    assert_equal 40.0, Setting.get("budget.spending_cap_usd")
  end

  test "the cap form has a real label and the page is reachable from the queue" do
    get spend_path
    assert_select "label[for=amount]", text: "Cap in US dollars"
    get leads_path
    assert_select "a[href='#{spend_path}']", text: "Spend"
  end
end
