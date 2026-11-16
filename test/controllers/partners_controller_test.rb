require "test_helper"

class PartnersControllerTest < ActionDispatch::IntegrationTest
  include PartnerTestHelper

  setup { Scoring::ApiKey.lookup = -> { "sk-test" } }
  teardown { Scoring::ApiKey.lookup = nil }

  test "the page lists staffing firms with why they are there, and says they are kept apart" do
    staffing_firm(name: "Talent Bridge", country: "Canada", employees: 120)
    lead(name: "Normal Lead")
    get partners_path

    assert_response :success
    assert_select "h1", text: "Partners: staffing firms"
    assert_select ".hint", text: /kept here, apart from your Hot and Warm queue and the Results numbers/
    assert_select "h2", text: "Talent Bridge"
    assert_select "h2", text: "Normal Lead", count: 0
    assert_select "p", text: /Why here:.*staffing/
    assert_select "a[href='https://www.talentbridge.com'][rel='noopener noreferrer']", text: "talentbridge.com"
  end

  test "the draft button shows its cost, asks for confirmation, and starts a tracked run" do
    staffing_firm
    get partners_path
    assert_select "form[action='#{pipeline_partner_draft_path}']" do |forms|
      assert_match(/Draft partnership messages for 1 firm\? This calls the Anthropic API: expected \$\d\.\d{4}, never more than/, forms.first["data-turbo-confirm"])
    end

    assert_enqueued_jobs 1, only: PartnerDraftingRunJob do
      post pipeline_partner_draft_path
    end
    assert_redirected_to partners_path
    assert_equal [ "draft", "running" ], PipelineRun.last.slice(:kind, :status).values
  end

  test "the safeguards apply: no cap, no key, nothing to draft and an active draft run all refuse" do
    staffing_firm
    Setting.reset("budget.spending_cap_usd")
    post pipeline_partner_draft_path
    assert_match(/No spending cap is set/, flash[:alert])

    Setting.set("budget.spending_cap_usd", 10)
    Scoring::ApiKey.lookup = -> { nil }
    post pipeline_partner_draft_path
    assert_match(/API key is not set/, flash[:alert])

    Scoring::ApiKey.lookup = -> { "sk-test" }
    PipelineRun.start!("draft")
    post pipeline_partner_draft_path
    assert_match(/already in progress/, flash[:alert])
    assert_equal 1, PipelineRun.count
  end

  test "with nothing to draft the page says so" do
    get partners_path
    assert_select ".panel", text: /No staffing firms found yet/
    post pipeline_partner_draft_path
    assert_equal "Nothing to partner right now.", flash[:alert]
  end

  test "a drafted message is shown to edit and copy, and can be marked sent and unmarked" do
    firm = staffing_firm
    Partnering::Recorder.new.call(firm, partner_reply)
    get partners_path
    assert_select "textarea.message-field", text: /open to collaborating|Open to collaborating/i
    assert_select "button", text: "Copy message"
    assert_select "h3 label", text: "Partnership"

    patch partner_sent_path(firm)
    assert_equal "sent", firm.messages.first.reload.status
    follow_redirect!
    assert_select "button[aria-pressed=true]", text: "Sent ✓ (undo)"

    patch partner_sent_path(firm)
    assert_equal "edited", firm.messages.first.reload.status
  end

  test "a contact can be added right on the partner card and the page returns to Partners" do
    firm = staffing_firm
    post lead_contact_path(firm), params: { return_to: "partners", contact: { first_name: "Dana", title: "CEO", linkedin_url: "https://www.linkedin.com/in/dana" } }
    assert_redirected_to partners_path
    assert_equal "Dana", firm.reload.selected_contact.first_name

    get partners_path
    assert_select "a[href='https://www.linkedin.com/in/dana']", text: "Open LinkedIn profile"
    assert_select "summary", text: "Add a contact yourself", count: 0
  end

  test "staffing firms never appear in the sales queue, the exports or the Results" do
    firm = staffing_firm
    Partnering::Recorder.new.call(firm, partner_reply)
    competitor = lead(name: "Competitor Co", tier: "Cold")
    competitor.current_evaluation.update!(disqualified: true)
    Partnering::Recorder.new.call(competitor, partner_reply)

    assert_empty Leads::Queue.new(tier: "Hot").companies.select { |c| [ firm, competitor ].include?(c) }
    assert_empty Leads::Queue.new(tier: "Warm").companies.select { |c| [ firm, competitor ].include?(c) }
    get root_path
    assert_select ".card-name", text: "Talent Bridge", count: 0
    assert_equal 0, OutreachSend.count
    assert_not_includes Company.awaiting_drafts, firm
    assert_not_includes Company.awaiting_drafts, competitor
  end

  test "the dashboard and queue link to the Partners page" do
    staffing_firm
    get dashboard_path
    assert_select "li", text: /Partners \(staffing firms\): 1 found, 0 with a message/
    assert_select "a[href='#{partners_path}']", text: "Open Partners"
    get root_path
    assert_select "a[href='#{partners_path}']", text: "Partners"
  end

  test "Not a staffing firm removes a firm from Partners, from drafting and from the counts, and it can be restored" do
    keep = staffing_firm(name: "Real Staffing")
    drop = staffing_firm(name: "Health Tech Co")
    Partnering::Recorder.new.call(drop, partner_reply)
    get partners_path
    assert_select "form[action='#{partner_dismiss_path(drop)}']" do |forms|
      assert_match(/Remove Health Tech Co from Partners\?.*restore it/, forms.first["data-turbo-confirm"])
    end

    patch partner_dismiss_path(drop)
    assert_redirected_to partners_path
    assert_match(/Removed from Partners/, flash[:notice])
    assert_equal [ keep ], Company.partner_candidates.to_a
    assert_not_includes Company.awaiting_partner_drafts, drop
    assert_nil Partnering::Drafter.new(gateway: FakeGateway.new).call(drop), "a dismissed firm is never drafted for"

    get partners_path
    assert_select "h2", text: "Health Tech Co", count: 0
    assert_select "summary", text: "Removed from Partners (1)"
    assert_select "li", text: /Health Tech Co/
    get dashboard_path
    assert_select "li", text: /Partners \(staffing firms\): 1 found/

    patch partner_restore_path(drop)
    assert_includes Company.partner_candidates, drop
    assert_equal 0, Company.partner_dismissed.count
  end
end
