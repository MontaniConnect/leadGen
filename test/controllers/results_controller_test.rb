require "test_helper"

# Same hand-counted dataset as Outreach::ReportTest (see the table there):
# 87 connection requests, 85 accepted, 82 messages, 19 replies, 7 positive, 1 call booked.
class ResultsControllerTest < ActionDispatch::IntegrationTest
  include OutreachTestHelper

  def seed_counted_data
    make_sends(40, replied: 10, positive: 4, booked: 1, variant: "curious_question", tier: "Hot", size: 30,
                   title: "CEO", industry: "Software", staffing: 9, automation: 5)
    make_sends(30, replied: 3, positive: 1, variant: "founder_time", tier: "Warm", size: 120,
                   title: "CTO", industry: "Logistics", staffing: 7, automation: 3)
    make_sends(12, replied: 6, positive: 2, variant: "low_pressure_offer", tier: "Cold", size: 15,
                   title: "Sales Manager", industry: "Software", staffing: 4, automation: 2)
    3.times { make_send(variant: "curious_question", messaged: false, accepted: true) }
    2.times { make_send(variant: "curious_question", messaged: false) }
  end

  def table_rows(heading_id, note: false)
    css_select("##{heading_id}-heading + #{'p + ' if note}table tbody tr").map { |row| row.css("td").map { |cell| cell.text.squish } }
  end

  test "an empty page says nothing is recorded yet" do
    get results_path
    assert_response :success
    assert_select ".panel", text: /Nothing recorded yet/
  end

  test "the funnel shows counts, percentages only for big enough groups, and the basis" do
    seed_counted_data
    get results_path

    rows = table_rows("funnel")
    assert_equal [ "Connection requests sent", "87", "all requests" ], rows[0]
    assert_equal [ "Connection accepted", "85 of 87 98%", "of requests sent" ], rows[1]
    assert_equal [ "Message sent", "82 of 85 96%", "of accepted" ], rows[2]
    assert_equal [ "Replied", "19 of 82 23%", "of messages sent" ], rows[3]
    assert_equal [ "Positive reply", "7 of 19 too few to judge", "of replies" ], rows[4]
    assert_equal [ "Call booked", "1 of 7 too few to judge", "of positive replies" ], rows[5]
  end

  test "by variant: every rate shows its count, and a group under 30 has no percentage" do
    seed_counted_data
    get results_path

    rows = table_rows("variant", note: true)
    assert_equal [ "Curious question", "40", "10 of 40 25%", "4 of 40 10%" ], rows[0]
    assert_equal [ "Founder-time angle", "30", "3 of 30 10%", "1 of 30 3%" ], rows[1]
    assert_equal [ "Low-pressure offer", "12", "6 of 12 too few to judge", "2 of 12 too few to judge" ], rows[2]
    assert_no_match(/%/, rows[2].join, "a sample of 12 must never show a percentage")
  end

  test "score check, size, title, score band and industry tables match the hand count" do
    seed_counted_data
    get results_path

    assert_equal [ "Hot", "40", "10 of 40 25%", "4 of 40 10%" ], table_rows("score-check", note: true)[0]
    assert_equal [ "Warm", "30", "3 of 30 10%", "1 of 30 3%" ], table_rows("score-check", note: true)[1]
    assert_equal [ "Cold", "12", "6 of 12 too few to judge", "2 of 12 too few to judge" ], table_rows("score-check", note: true)[2]
    assert_equal [ "CEO / Founder", "CTO", "Other" ], table_rows("title").map(&:first)
    assert_equal [ "10-24", "25-49", "100-200" ], table_rows("size").map(&:first)
    assert_equal [ "9-10", "7-8", "1-4" ], table_rows("score-band").map(&:first)
    assert_equal [ "Software", "52", "16 of 52 31%", "6 of 52 12%" ], table_rows("industry").find { |row| row[0] == "Software" }
    assert_equal [ "Logistics", "30", "3 of 30 10%", "1 of 30 3%" ], table_rows("industry").find { |row| row[0] == "Logistics" }
  end

  test "the page explains the random share and the sample rule" do
    seed_counted_data
    get results_path
    assert_select ".hint", text: /at least 30 messages/
    assert_select "#variant-heading + p", text: /82 of 82 messages were assigned at random/
  end

  test "below 30 messages no suggestions are shown, only how far along it is" do
    make_sends(12, replied: 6, variant: "curious_question")
    get results_path
    assert_select ".panel", text: /Suggestions appear after 30 messages have been sent. So far: 12/
    assert_select "button", text: /Approve|drafting example/, count: 0
  end

  test "a clear winner is offered for approval, and approving stores it for review and use" do
    make_sends(30, replied: 12, variant: "curious_question")
    make_sends(30, replied: 6, variant: "founder_time")
    get results_path
    assert_select "button", text: "Approve as default"
    assert_select "td", text: /Curious question: 12 of 30/

    post results_defaults_path(dimension: "tier", segment: "Hot", variant: "curious_question")
    assert_redirected_to results_path
    assert_equal({ "tier:Hot" => "curious_question" }, Outreach::Approvals.new.defaults)

    get results_path
    assert_select "h3", text: "Approved defaults"
    assert_select "li", text: /Tier: Hot.*Curious question/m
    assert_select ".hint", text: /30% of sends are still assigned at random/
    assert_select ".tag.sent", text: "Approved"

    delete results_defaults_path(key: "tier:Hot")
    assert_empty Outreach::Approvals.new.defaults
  end

  test "only a currently supported suggestion can be approved, never an arbitrary one" do
    make_sends(30, replied: 12, variant: "curious_question")
    make_sends(30, replied: 6, variant: "founder_time")

    post results_defaults_path(dimension: "tier", segment: "Hot", variant: "founder_time")
    assert_equal "That suggestion is not supported by enough data.", flash[:alert]
    post results_defaults_path(dimension: "tier", segment: "Warm", variant: "curious_question")
    assert_match(/not supported/, flash[:alert])
    assert_empty Outreach::Approvals.new.defaults
  end

  test "a positive-reply message can be approved as a drafting example; others cannot" do
    make_sends(30, variant: "curious_question")
    winner = make_send(replied: true, positive: true, sent_body: "Hi Ada, the good one?")
    plain = make_send(replied: true, sent_body: "Hi Sam, only replied?")

    get results_path
    assert_select "blockquote", text: "Hi <first name>, the good one?"
    assert_select "button", text: "Use as drafting example", count: 1

    post results_example_path(winner.id)
    assert_equal [ winner.id ], Outreach::Approvals.new.example_ids
    post results_example_path(plain.id)
    assert_equal "That message cannot be used as an example yet.", flash[:alert]
    assert_equal [ winner.id ], Outreach::Approvals.new.example_ids

    delete results_example_path(winner.id)
    assert_empty Outreach::Approvals.new.example_ids
  end

  test "rule changes are advice with no apply button" do
    make_sends(30, replied: 3, variant: "curious_question", tier: "Hot")
    make_sends(30, replied: 12, variant: "curious_question", tier: "Warm")
    get results_path

    assert_select "h3", text: "Suggested rule changes (advice only)"
    assert_select "li.flags strong", text: "Warm leads are replying more than Hot leads"
    assert_select "li.flags button", count: 0
    assert_select "li.flags form", count: 0
  end

  test "the page is linked from the queue and has no unnamed controls" do
    seed_counted_data
    get leads_path
    assert_select "a[href='#{results_path}']", text: "Results"
    get results_path
    css_select("button, input[type=submit]").each { |control| assert((control.text.presence || control["value"]).present?) }
  end
end
