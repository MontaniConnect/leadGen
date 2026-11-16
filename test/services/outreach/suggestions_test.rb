require "test_helper"

class Outreach::SuggestionsTest < ActiveSupport::TestCase
  include OutreachTestHelper

  def suggestions = Outreach::Suggestions.new(sends: OutreachSend.includes(:contact, :company).to_a)
  def tier_defaults = suggestions.variant_defaults.select { |s| s.dimension == "tier" }

  # Hot leads: curious replies 12 of 30 (40%), founder 6 of 30 (20%): a 20-point gap.
  def seed_clear_winner(**attrs)
    make_sends(30, replied: 12, variant: "curious_question", **attrs)
    make_sends(30, replied: 6, variant: "founder_time", **attrs)
  end

  test "nothing is suggested until 30 messages have been sent in total" do
    make_sends(29, replied: 20, variant: "curious_question")
    assert_not suggestions.enough_data?
    assert_empty suggestions.variant_defaults
    assert_empty suggestions.rule_changes
    assert_empty suggestions.example_candidates
  end

  test "a clear winner with 30+ random sends per variant is suggested, with the counts behind it" do
    seed_clear_winner
    suggestion = tier_defaults.first

    assert_equal [ "tier", "Hot", "curious_question", "Curious question" ], suggestion.to_h.values_at(:dimension, :segment, :variant, :variant_name)
    assert_equal({ "curious_question" => "12 of 30", "founder_time" => "6 of 30" }, suggestion.cells.transform_values(&:to_s))
    assert_not suggestion.approved
  end

  test "a gap under 10 points is not a suggestion" do
    make_sends(30, replied: 12, variant: "curious_question")  # 40%
    make_sends(30, replied: 10, variant: "founder_time")      # 33%: 7 points
    assert_empty tier_defaults
  end

  test "a variant with fewer than 30 sends in the segment cannot be compared" do
    make_sends(30, replied: 15, variant: "curious_question")
    make_sends(29, replied: 1, variant: "founder_time")
    assert_empty tier_defaults
  end

  test "only randomly assigned sends count: manual and suggested picks cannot bias the comparison" do
    seed_clear_winner
    make_sends(40, replied: 40, variant: "founder_time", assignment: "manual")
    make_sends(40, replied: 40, variant: "founder_time", assignment: "suggested")

    assert_equal "curious_question", tier_defaults.first.variant, "the 80 hand-picked and defaulted sends are ignored"
    assert_equal "6 of 30", tier_defaults.first.cells["founder_time"].to_s
  end

  test "segments are judged separately: a winner in Hot says nothing about Warm" do
    seed_clear_winner(tier: "Hot")
    make_sends(30, replied: 6, variant: "curious_question", tier: "Warm")
    make_sends(30, replied: 12, variant: "founder_time", tier: "Warm")

    winners = tier_defaults.to_h { |s| [ s.segment, s.variant ] }
    assert_equal({ "Hot" => "curious_question", "Warm" => "founder_time" }, winners)
  end

  test "an already approved default is marked approved" do
    seed_clear_winner
    Outreach::Approvals.new.approve_default!("tier", "Hot", "curious_question")
    assert tier_defaults.first.approved
  end

  test "example candidates are positive-reply messages, booked calls first, with names removed" do
    make_sends(30, replied: 0, variant: "curious_question")
    interested = make_send(replied: true, positive: true, sent_body: "Hi Ada, interested one?")
    booked = make_send(replied: true, positive: true, booked: true, sent_body: "Hi Sam, booked one?")
    make_send(replied: true, sent_body: "Hi Lee, replied only?")

    candidates = suggestions.example_candidates
    assert_equal [ booked.id, interested.id ], candidates.map { |c| c.send_record.id }, "replies without a positive outcome are never examples"
    assert_equal "Hi <first name>, booked one?", candidates.first.text
  end

  test "a lower-ranked tier replying better than a higher one raises a scoring suggestion" do
    make_sends(30, replied: 3, variant: "curious_question", tier: "Hot")    # 10%
    make_sends(30, replied: 12, variant: "curious_question", tier: "Warm")  # 40%
    change = suggestions.rule_changes.find { |c| c.title.include?("Warm leads are replying more than Hot") }

    assert_not_nil change
    assert_includes change.evidence, "Warm: 12 of 30 replied. Hot: 3 of 30 replied."
    assert_includes change.how, "scoring.hot_min_score (now 7)"
    assert_includes change.how, "Review"
  end

  test "no scoring suggestion when the tiers behave as expected" do
    make_sends(30, replied: 12, variant: "curious_question", tier: "Hot")
    make_sends(30, replied: 3, variant: "curious_question", tier: "Warm")
    assert_empty suggestions.rule_changes.select { |c| c.title.include?("replying more than") }
  end

  test "the smallest size band replying much worse suggests raising the minimum, never applying it" do
    make_sends(30, replied: 2, variant: "curious_question", size: 15)    # 10-24: 7%
    make_sends(60, replied: 24, variant: "curious_question", size: 60)   # others: 40%
    change = suggestions.rule_changes.find { |c| c.title.include?("10-24") }

    assert_not_nil change
    assert_includes change.how, "prefilter.min_employees from 10 to 25"
    assert_equal 10, Setting.get("prefilter.min_employees"), "nothing is changed automatically"
  end

  test "an industry replying much worse is flagged as advice only" do
    make_sends(30, replied: 1, variant: "curious_question", industry: "Education")
    make_sends(60, replied: 24, variant: "curious_question", industry: "Software")
    change = suggestions.rule_changes.find { |c| c.title.include?("Education") }

    assert_not_nil change
    assert_includes change.how, "suggestion only"
    assert_includes Setting.get("prefilter.excluded_keywords").to_s, "bpo"
    assert_not_includes Setting.get("prefilter.excluded_keywords"), "education"
  end

  test "small groups never produce a rule suggestion however bad they look" do
    make_sends(29, replied: 0, variant: "curious_question", size: 15)
    make_sends(60, replied: 40, variant: "curious_question", size: 60)
    assert_empty suggestions.rule_changes.select { |c| c.title.include?("10-24") }
  end
end
