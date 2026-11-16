require "test_helper"

# Hand-counted dataset. Every expected figure below was worked out by hand from this table:
#
#   Group   Variant        Tier  Size  Title          Industry   Best score  Sent  Replied  Positive  Booked
#   A       curious        Hot   30    CEO            Software   9           40    10       4         1
#   B       founder_time   Warm  120   CTO            Logistics  7           30    3        1         0
#   C       low_pressure   Cold  15    Sales Manager  Software   4           12    6        2         0
#   D       (connection requests only, not messaged)                          5 sends, 3 accepted
#
#   Totals: 87 connection requests, 85 accepted (82 messaged + 3), 82 messages, 19 replies, 7 positive, 1 call booked.
class Outreach::ReportTest < ActiveSupport::TestCase
  include OutreachTestHelper

  setup do
    make_sends(40, replied: 10, positive: 4, booked: 1, variant: "curious_question", tier: "Hot", size: 30,
                   title: "CEO", industry: "Software", staffing: 9, automation: 5)
    make_sends(30, replied: 3, positive: 1, variant: "founder_time", tier: "Warm", size: 120,
                   title: "CTO", industry: "Logistics", staffing: 7, automation: 3)
    make_sends(12, replied: 6, positive: 2, variant: "low_pressure_offer", tier: "Cold", size: 15,
                   title: "Sales Manager", industry: "Software", staffing: 4, automation: 2)
    3.times { make_send(variant: "curious_question", messaged: false, accepted: true) }
    2.times { make_send(variant: "curious_question", messaged: false, accepted: false) }
    @report = Outreach::Report.new
  end

  def rows(dimension) = @report.breakdown(dimension).to_h { |row| [ row.label, [ row.sent.total, row.reply.to_s, row.positive.to_s ] ] }

  test "the funnel counts each stage against the one before" do
    stages = @report.funnel.to_h { |stage| [ stage.label, stage.cell.to_s ] }
    assert_equal({
      "Connection requests sent" => "87 of 87", "Connection accepted" => "85 of 87", "Message sent" => "82 of 85",
      "Replied" => "19 of 82", "Positive reply" => "7 of 19", "Call booked" => "1 of 7"
    }, stages)
  end

  test "by variant: counts of messages sent, replies and positive replies" do
    assert_equal({
      "Curious question" => [ 40, "10 of 40", "4 of 40" ],
      "Founder-time angle" => [ 30, "3 of 30", "1 of 30" ],
      "Low-pressure offer" => [ 12, "6 of 12", "2 of 12" ]
    }, rows("variant"))
  end

  test "score check by tier at send time, in Hot, Warm, Cold order" do
    assert_equal %w[Hot Warm Cold], @report.breakdown("tier").map(&:label)
    assert_equal [ 40, "10 of 40" ], rows("tier")["Hot"].first(2)
    assert_equal [ 30, "3 of 30" ], rows("tier")["Warm"].first(2)
    assert_equal [ 12, "6 of 12" ], rows("tier")["Cold"].first(2)
  end

  test "by contact title, company size, best score and industry" do
    assert_equal [ 40, "10 of 40" ], rows("title")["CEO / Founder"].first(2)
    assert_equal [ 30, "3 of 30" ], rows("title")["CTO"].first(2)
    assert_equal [ 12, "6 of 12" ], rows("title")["Other"].first(2)

    assert_equal %w[10-24 25-49 100-200], @report.breakdown("size").map(&:label)
    assert_equal [ 40, "10 of 40" ], rows("size")["25-49"].first(2)
    assert_equal [ 30, "3 of 30" ], rows("size")["100-200"].first(2)

    assert_equal %w[9-10 7-8 1-4], @report.breakdown("score").map(&:label)
    assert_equal [ 40, "10 of 40" ], rows("score")["9-10"].first(2)

    assert_equal [ 52, "16 of 52", "6 of 52" ], rows("industry")["Software"] # A + C
    assert_equal [ 30, "3 of 30", "1 of 30" ], rows("industry")["Logistics"]
  end

  test "a group of 30 or more is reliable; below that it is not" do
    by_variant = @report.breakdown("variant").to_h { |row| [ row.label, @report.reliable?(row.reply) ] }
    assert_equal({ "Curious question" => true, "Founder-time angle" => true, "Low-pressure offer" => false }, by_variant)
    assert_not @report.reliable?(Outreach::Cell.new(7, 19)), "7 of 19 is too few"
    assert @report.reliable?(Outreach::Cell.new(0, 30)), "exactly 30 counts"
    assert_not @report.reliable?(Outreach::Cell.new(29, 29))
  end

  test "connection-only sends never inflate a rate's denominator" do
    assert_equal 82, @report.messaged.size
    assert_equal 82, @report.breakdown("variant").sum { |row| row.sent.total }
  end

  test "rates are computed from counts, never rounded counts" do
    cell = @report.breakdown("variant").first.reply
    assert_in_delta 0.25, cell.rate
    assert_nil Outreach::Cell.new(0, 0).rate
  end

  test "an empty report has no rows and does not divide by zero" do
    empty = Outreach::Report.new(sends: [])
    assert empty.empty?
    assert_equal [ "0 of 0" ] * 6, empty.funnel.map { |stage| stage.cell.to_s }
    assert_empty empty.breakdown("variant")
  end

  test "sends without a variant appear in the funnel but not in the variant table" do
    make_send(variant: nil, assignment: "manual", messaged: false)
    report = Outreach::Report.new
    assert_equal "88 of 88", report.funnel.first.cell.to_s
    assert_equal 82, report.breakdown("variant").sum { |row| row.sent.total }
  end
end
