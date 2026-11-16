require "test_helper"

class Pilot::PilotTest < ActiveSupport::TestCase
  include DraftingTestHelper

  PATH = Rails.root.join("test/fixtures/files/pilot_accounts.csv").to_s

  def intake(count: 10, seed: 42, out: StringIO.new, csv: Tempfile.new([ "pilot", ".csv" ]).path)
    Pilot::Intake.new(path: PATH, count: count, seed: seed, out: out, csv_path: csv).call
  end

  test "imports only the sampled rows, remembers them, and runs the prefilter on them" do
    batch = intake(count: 10)

    assert_equal 10, batch.rows_created
    assert_equal 10, Company.count
    assert_equal Company.pluck(:id).sort, Pilot.scope.pluck(:id).sort
    assert Company.all.none? { |company| company.prefilter_status == "pending" }
  end

  test "the same seed picks the same companies, a different seed picks others" do
    intake(seed: 1)
    first = Pilot.scope.pluck(:name).sort
    Company.destroy_all
    intake(seed: 1)
    assert_equal first, Pilot.scope.pluck(:name).sort

    Company.destroy_all
    intake(seed: 2)
    assert_not_equal first, Pilot.scope.pluck(:name).sort
  end

  test "repeating the intake is safe: no duplicates and the same pilot set" do
    intake
    ids = Pilot.scope.pluck(:id).sort
    second = intake
    assert_equal 0, second.rows_created
    assert_equal 10, Company.count
    assert_equal ids, Pilot.scope.pluck(:id).sort
  end

  test "every decision is printed with its reason and a mark-up CSV is written" do
    out = StringIO.new
    csv = Rails.root.join("tmp/pilot_test_#{SecureRandom.hex(4)}.csv").to_s
    intake(count: 40, out: out, csv: csv)

    assert_match(/^PASS\s+Company/, out.string)
    assert_match(/^FAIL\s+Company \d\d\s+900\s+United States\s+employees_above_max/, out.string)
    assert_match(/excluded_keyword: staffing/, out.string)
    assert_match(/country_not_allowed/, out.string)
    assert_includes out.string, "Check each decision by hand"

    rows = CSV.read(csv, headers: true)
    assert_equal Pilot::Intake::HEADERS, rows.headers
    assert_equal 40, rows.size
    assert rows.all? { |row| row["Your verdict"].nil? || row["Your verdict"].empty? }
    assert_includes rows.map { |row| row["Result"] }, "FAIL"
  ensure
    FileUtils.rm_f(csv)
  end

  test "changing a rule and re-running the prefilter changes the pilot's verdicts" do
    intake(count: 40)
    before = Pilot.scope.prefilter_passed.count
    Setting.set("prefilter.max_employees", 5000)
    Prefilter::Runner.new(scope: Pilot.scope).call
    assert_operator Pilot.scope.prefilter_passed.count, :>, before
  end

  test "the pilot scope keeps other companies out of every step" do
    intake(count: 5)
    outsider = company_with_pages(name: "Outsider")
    assert_not_includes Pilot.scope, outsider

    result = Budget::DryRun.new.call(scope: Pilot.scope)
    assert_operator result.stages.first.companies, :<=, 5
    assert_not_includes Company.awaiting_evaluation.where(id: Pilot.scope.select(:id)), outsider
  end

  test "fetch step touches only pilot companies that passed" do
    intake(count: 20)
    calls = []
    fetcher = Object.new
    fetcher.define_singleton_method(:call) do |company|
      calls << company.name
      Fetching::CompanyFetcher::Outcome.new(0, 0, nil)
    end
    outsider = Company.create!(name: "Outsider", domain: "outsider.com", prefilter_status: "pass")

    Pilot::Fetch.new(fetcher: fetcher, out: StringIO.new).call

    assert_equal Pilot.scope.prefilter_passed.where.not(domain: nil).pluck(:name).sort, calls.sort
    assert_not_includes calls, outsider.name
  end

  test "the report has one line per pilot company with tier, scores, drafts and cost" do
    intake(count: 3)
    lead = Pilot.scope.first
    lead.update!(prefilter_status: "pass")
    Scoring::Recorder.new.call(lead, reply)
    out = StringIO.new
    Pilot::Report.new(out: out).call

    lines = out.string.lines
    assert_equal 4, lines.size
    assert_match(/#{lead.name}\s+pass\s.*Warm\/L\s+8\/6\s+0\s+\$0\.0002/, out.string)
  end

  test "CsvRows#sample is reproducible and keeps file order" do
    rows = Imports::CsvRows.new(PATH)
    a = rows.sample(8, seed: 5)
    assert_equal a, rows.sample(8, seed: 5)
    assert_equal a.map(&:first).sort, a.map(&:first)
    assert_equal 8, a.size
    assert_equal 40, rows.sample(500, seed: 5).size, "asking for more than exist returns them all"
  end
end
