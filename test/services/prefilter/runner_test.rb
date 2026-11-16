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
end
