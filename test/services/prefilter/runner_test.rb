require "test_helper"

class Prefilter::RunnerTest < ActiveSupport::TestCase
  setup do
    Company.create!(name: "Good", employees: 50, country: "United States", technologies: "AWS")
    Company.create!(name: "Tiny", employees: 2, country: "United States")
  end

  test "stores verdicts and reasons and reports counts" do
    tally = Prefilter::Runner.new.call

    assert_equal({ "pass" => 1, "fail" => 1 }, tally)
    good = Company.find_by!(name: "Good")
    assert_equal "pass", good.prefilter_status
    assert_equal [ "technology: AWS" ], good.prefilter_boosts
    assert_equal [ "employees_below_min" ], Company.find_by!(name: "Tiny").prefilter_reasons
  end

  test "rules come from Settings and can change without code" do
    Setting.set("prefilter.min_employees", 1)
    Prefilter::Runner.new.call
    assert_equal "pass", Company.find_by!(name: "Tiny").prefilter_status
  end

  test "report counts per reason" do
    Prefilter::Runner.new.call
    report = Prefilter::Report.new

    assert_equal({ "employees_below_min" => 1 }, report.reason_counts)
    assert_equal({ "pass" => 1, "fail" => 1 }, report.status_counts)
  end

  test "the shipped country list: US plus Canada, UK, Australia and New Zealand pass; other countries do not" do
    allowed = [ "United States", "USA", "Canada", "United Kingdom", "UK", "Australia", "New Zealand", "australia", "CANADA" ]
    rejected = [ "Germany", "India", "France", "Netherlands", "Italy", "Tuerkiye", "Ireland" ]
    (allowed + rejected).each_with_index do |country, index|
      Company.create!(name: "C#{index}", employees: 50, country: country)
    end
    Prefilter::Runner.new.call

    passed = Company.where(prefilter_status: "pass", name: (0...(allowed.size + rejected.size)).map { |i| "C#{i}" }).pluck(:country)
    assert_equal allowed.sort, passed.sort
    assert_equal rejected.sort, Company.where(prefilter_status: "fail").where("name LIKE 'C%'").where.not(name: %w[Tiny]).pluck(:country).sort
    assert_equal [ "country_not_allowed" ], Company.find_by!(country: "Germany").prefilter_reasons
  end
end
