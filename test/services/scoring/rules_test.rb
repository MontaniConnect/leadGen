require "test_helper"

class Scoring::RulesTest < ActiveSupport::TestCase
  def pair(result) = [ result.level, result.useful_sources ]

  def tier(staffing, automation, confidence, disqualified: false)
    Scoring::TierRule.new.call(staffing: staffing, automation: automation, confidence: confidence, disqualified: disqualified)
  end

  test "hot needs a 7+ score and medium or high confidence" do
    assert_equal "Hot", tier(7, 3, "Medium")
    assert_equal "Hot", tier(2, 9, "High")
    assert_equal "Warm", tier(7, 3, "Low")
  end

  test "warm needs a 5+ score, otherwise cold" do
    assert_equal "Warm", tier(5, 4, "High")
    assert_equal "Cold", tier(4, 4, "High")
  end

  test "a disqualified company is always cold" do
    assert_equal "Cold", tier(10, 10, "High", disqualified: true)
  end

  test "thresholds come from settings" do
    Setting.set("scoring.hot_min_score", 9)
    assert_equal "Warm", tier(8, 3, "High")
  end

  test "confidence counts ok pages plus a useful Apollo profile" do
    company = Company.create!(name: "A", short_description: "software")
    assert_equal [ "Low", 1 ], pair(Scoring::Confidence.new.call(company))
    %w[home about].each { |k| company.pages.create!(kind: k, status: "ok", text: "x") }
    company.pages.create!(kind: "blog", status: "not_found")
    assert_equal [ "Medium", 3 ], pair(Scoring::Confidence.new.call(company.reload))
    company.pages.find_by!(kind: "blog").update!(status: "ok")
    assert_equal [ "Medium", 4 ], pair(Scoring::Confidence.new.call(company.reload))
  end

  test "five useful sources is High" do
    company = Company.create!(name: "A", keywords: "saas")
    %w[home about careers blog].each { |k| company.pages.create!(kind: k, status: "ok", text: "x") }
    assert_equal [ "High", 5 ], pair(Scoring::Confidence.new.call(company))
  end

  test "no description or keywords and no pages is Low with zero sources" do
    assert_equal [ "Low", 0 ], pair(Scoring::Confidence.new.call(Company.create!(name: "Bare")))
  end
end
