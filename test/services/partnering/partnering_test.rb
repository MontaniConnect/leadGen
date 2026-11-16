require "test_helper"

class Partnering::PartneringTest < ActiveSupport::TestCase
  include PartnerTestHelper

  def drafter(gateway, **options) = Partnering::Drafter.new(gateway: gateway, **options)

  test "partner candidates: filter-excluded staffing firms and scorer-flagged competitors, nobody else" do
    keyword = staffing_firm(name: "Keyword Staffing")
    naics = staffing_firm(name: "Naics Co", reasons: [ "excluded_naics: 5613" ])
    competitor = lead(name: "Competitor Co", tier: "Cold")
    competitor.current_evaluation.update!(disqualified: true)
    too_big = staffing_firm(name: "Huge Staffing", reasons: [ "employees_above_max", "excluded_keyword: staffing" ])
    wrong_country_only = staffing_firm(name: "Foreign Co", reasons: [ "country_not_allowed" ])
    normal_lead = lead(name: "Normal Lead")
    plain_cold = lead(name: "Plain Cold", tier: "Cold")

    candidates = Company.partner_candidates
    assert_equal [ competitor, keyword, naics, too_big ].map(&:id).sort, candidates.pluck(:id).sort
    [ wrong_country_only, normal_lead, plain_cold ].each { |company| assert_not_includes candidates, company }
  end

  test "a firm that already has a partnership message is no longer awaiting one" do
    firm = staffing_firm
    assert_includes Company.awaiting_partner_drafts, firm
    firm.messages.create!(label: "partnership", body: "Hi, quick one?")
    assert_not_includes Company.awaiting_partner_drafts, firm
  end

  test "the request is for peers: cached instructions about collaboration, the firm's facts, and the reason" do
    firm = staffing_firm(short_description: "Places IT contractors in healthcare", keywords: "staffing, healthcare it")
    contact = firm.contacts.create!(first_name: "Dana", title: "CEO")
    firm.update!(selected_contact: contact)
    request = Partnering::RequestBuilder.new.call(firm)

    assert_equal "claude-sonnet-5-5", request[:model]
    assert_equal({ type: "ephemeral", ttl: "1h" }, request[:system_].first[:cache_control])
    assert_includes request[:system_].first[:text], "open to collaborating, or to overlapping in the future"
    assert_includes request[:system_].first[:text], "A peer, not a buyer"
    assert_includes request[:system_].first[:text], "PERSONALIZE (this matters most)"
    assert_includes request[:system_].first[:text], "could go unchanged to any staffing firm is wrong"
    content = request[:messages].first[:content]
    assert_includes content, "Contact first name: Dana"
    assert_includes content, "Description: Places IT contractors in healthcare"
    assert_includes content, "Apollo lists it under staffing (staffing, recruiting or outsourcing)"
    assert_empty request.keys & %i[temperature top_p top_k tool_choice]
  end

  test "a competitor's reason is the scorer's own red flag" do
    firm = lead(name: "Competitor Co", tier: "Cold")
    firm.current_evaluation.update!(disqualified: true, red_flags: [ { "flag" => "Places talent with tech enterprises", "source" => "Apollo" } ])
    assert_equal "Scored as a competitor: Places talent with tech enterprises", Partnering::EvidenceFormatter.new.reason(firm.reload)
  end

  test "a valid reply becomes one partnership draft with its cost, tokens and contact" do
    firm = staffing_firm
    contact = firm.contacts.create!(first_name: "Dana", title: "CEO")
    firm.update!(selected_contact: contact)
    run = Partnering::Recorder.new.call(firm, partner_reply)

    assert_equal "ok", run.status
    message = firm.messages.find_by!(label: "partnership")
    assert_equal [ "draft", contact, "p2", PARTNER_BODY ], [ message.status, message.contact, message.prompt_version, message.body ]
    assert_operator message.word_count, :<=, 50
    assert_equal BigDecimal("0.00344"), run.cost_usd
  end

  test "the same checks as lead messages: over 50 words, no closing question, flattery and bad JSON are all rejected" do
    firm = staffing_firm
    {
      "over_word_limit" => partner_reply("#{'word ' * 55}?"),
      "no_closing_question" => partner_reply("Hi Dana, happy to collaborate."),
      "banned_phrase: impressive" => partner_reply("Hi Dana, your firm is impressive. Open to collaborating?"),
      "invalid JSON" => reply("nope")
    }.each do |expected, bad|
      run = Partnering::Recorder.new.call(firm, bad)
      assert_equal "failed", run.status
      assert_includes run.error, expected
    end
    assert_equal 0, firm.messages.count
  end

  test "re-drafting replaces an unedited draft but never an edited or sent message" do
    firm = staffing_firm
    Partnering::Recorder.new.call(firm, partner_reply)
    firm.messages.first.update!(status: "sent")
    Partnering::Recorder.new.call(firm, partner_reply)
    assert_equal [ "sent", "draft" ], firm.messages.order(:id).pluck(:status)
  end

  test "the drafter skips non-candidates and firms already drafted, with no API call" do
    gateway = FakeGateway.new(replies: [ partner_reply ])
    assert_nil drafter(gateway).call(lead(name: "Normal Lead"))
    firm = staffing_firm
    assert_equal "ok", drafter(gateway).call(firm).status
    assert_nil drafter(FakeGateway.new).call(firm)
    assert_equal 1, gateway.requests.size
  end

  test "an invalid first reply is retried once, and every attempt is logged" do
    firm = staffing_firm
    run = drafter(FakeGateway.new(replies: [ partner_reply("no question here"), partner_reply ])).call(firm)
    assert_equal "ok", run.status
    assert_equal %w[failed ok], firm.draft_runs.order(:id).pluck(:status)
  end

  test "the drafter stops at the spending cap before calling the API" do
    firm = staffing_firm
    Setting.set("budget.spending_cap_usd", 0.0001)
    gateway = FakeGateway.new(replies: [ partner_reply ])
    assert_raises(Budget::Guard::CapReached) { drafter(gateway).call(firm) }
    assert_empty gateway.requests
  end

  test "a partnership run is tracked, costed and uses the draft lock" do
    staffing_firm
    out = StringIO.new
    run = Pipeline::PartnerDraftingRun.new(gateway: FakeGateway.new(replies: [ partner_reply ]), out: out).call
    assert_equal [ "draft", "complete" ], [ run.kind, run.status ]
    assert_equal 1, run.draft_runs.count
    assert_includes out.string, "partnership message drafted"
  end

  test "people imports can now give a staffing firm a contact" do
    firm = staffing_firm
    firm.contacts.create!(first_name: "Dana", title: "CEO", source: "apollo")
    Contacts::Runner.new.call
    assert_equal "Dana", firm.reload.selected_contact.first_name
  end
end
