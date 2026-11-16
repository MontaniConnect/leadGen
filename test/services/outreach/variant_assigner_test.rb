require "test_helper"

class Outreach::VariantAssignerTest < ActiveSupport::TestCase
  LABELS = %w[curious_question founder_time low_pressure_offer].freeze
  SEGMENTS = { "tier" => "Hot", "title" => "CEO / Founder", "size" => "25-49", "industry" => "Software", "score" => "9-10" }.freeze

  def assigner(**options) = Outreach::VariantAssigner.new(rng: Random.new(2026), **options)

  def draw(assigner, times, labels: LABELS)
    Array.new(times) { assigner.call(labels: labels, segments: SEGMENTS) }
  end

  test "by default every variant gets a fair share, recorded as random" do
    draws = draw(assigner, 3000)

    assert_equal [ "random" ], draws.map(&:assignment).uniq
    LABELS.each do |label|
      share = draws.count { |choice| choice.variant == label } / 3000.0
      assert_in_delta 1 / 3.0, share, 0.04, "#{label} got #{(share * 100).round}%"
    end
  end

  test "only the variants a lead actually has can be assigned" do
    draws = draw(assigner, 200, labels: %w[curious_question low_pressure_offer])
    assert_equal %w[curious_question low_pressure_offer], draws.map(&:variant).uniq.sort
  end

  test "a lead with no drafts gets no variant, recorded as manual" do
    choice = assigner.call(labels: [], segments: SEGMENTS)
    assert_nil choice.variant
    assert_equal "manual", choice.assignment
  end

  test "an approved default is used most of the time, and the rest stays random so testing continues" do
    Outreach::Approvals.new.approve_default!("tier", "Hot", "founder_time")
    draws = draw(assigner, 3000)

    suggested = draws.select { |choice| choice.assignment == "suggested" }
    assert_in_delta 0.7, suggested.size / 3000.0, 0.04, "70% of sends use the default (explore_share is 0.3)"
    assert_equal [ "founder_time" ], suggested.map(&:variant).uniq
    random = draws.select { |choice| choice.assignment == "random" }
    assert_equal LABELS.sort, random.map(&:variant).uniq.sort, "exploration still covers every variant"
  end

  test "the exploration share is a setting" do
    Outreach::Approvals.new.approve_default!("tier", "Hot", "founder_time")
    all_default = draw(assigner(explore_share: 0.0), 100)
    assert_equal [ "suggested" ], all_default.map(&:assignment).uniq
    all_random = draw(assigner(explore_share: 1.0), 100)
    assert_equal [ "random" ], all_random.map(&:assignment).uniq
  end

  test "an approved default the lead has no draft for falls back to random" do
    Outreach::Approvals.new.approve_default!("tier", "Hot", "founder_time")
    draws = draw(assigner(explore_share: 0.0), 100, labels: %w[curious_question low_pressure_offer])
    assert_equal [ "random" ], draws.map(&:assignment).uniq
    assert_not_includes draws.map(&:variant), "founder_time"
  end
end
