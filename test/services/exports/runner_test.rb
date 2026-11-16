require "test_helper"

class Exports::RunnerTest < ActiveSupport::TestCase
  include LeadsTestHelper

  setup do
    @batch = ImportBatch.create!(kind: "accounts", filename: "q4.csv")
    lead(name: "HotNew", staffing: 9, automation: 5, import_batch: @batch, apollo_account_id: "a1")
    lead(name: "HotSent", staffing: 8, automation: 5, connection_sent_at: Time.current, apollo_account_id: "a2")
    lead(name: "HotReplied", staffing: 7, automation: 5, reply_result: "replied", connection_sent_at: Time.current)
    lead(name: "WarmOne", tier: "Warm", staffing: 6, automation: 5)
    lead(name: "ColdOne", tier: "Cold", staffing: 2, automation: 2)
  end

  def run_export(format: "csv", scope: "view", **filters)
    export = Export.create!(file_format: format, scope: scope, filters: filters)
    Exports::Runner.new.call(export)
    export.reload
  end

  def csv_of(export) = CSV.parse(export.data.dup.force_encoding("UTF-8").delete_prefix("\uFEFF"), headers: true)

  def csv_names(export) = csv_of(export).map { |row| row["Company"] }

  def screen_names(**filters) = Leads::Queue.new(**filters).companies.map(&:name)

  test "an export matches exactly what the same filters show on screen, in the same order" do
    [
      {},
      { tier: "Warm" },
      { tier: "Hot", status: "to_contact" },
      { tier: "Hot", status: "sent" },
      { tier: "Hot", reply: "replied" },
      { tier: "Hot", reply: "none" },
      { tier: "Hot", batch: @batch.id.to_s },
      { tier: "Hot", status: "to_contact", batch: @batch.id.to_s }
    ].each do |filters|
      export = run_export(**filters)
      assert export.done?, "export failed for #{filters}: #{export.error}"
      assert_equal screen_names(**filters), csv_names(export), "mismatch for #{filters}"
      assert_equal screen_names(**filters).size, export.row_count
    end
  end

  test "XLSX contains the same rows as CSV" do
    csv = run_export(tier: "Hot")
    xlsx = run_export(format: "xlsx", tier: "Hot")

    assert_equal csv_names(csv), XlsxReader.rows(xlsx.data).drop(1).map(&:first)
    assert_equal Exports::Row::HEADERS, XlsxReader.rows(xlsx.data).first
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", xlsx.content_type
  end

  test "export all includes every tier including Cold" do
    assert_equal %w[HotNew HotSent HotReplied WarmOne ColdOne], csv_names(run_export(scope: "all"))
  end

  test "export is not capped at the 300 rows the screen lists" do
    stub_const = Leads::Queue::LIMIT
    assert_equal 300, stub_const
    Company.insert_all(Array.new(310) { |i| { name: "Bulk #{i}", prefilter_status: "pass", created_at: Time.current, updated_at: Time.current } })
    Company.where("name LIKE 'Bulk %'").find_each do |company|
      company.evaluations.create!(status: "ok", tier: "Warm", staffing_score: 5, automation_score: 5, confidence: "Low")
    end

    export = run_export(tier: "Warm")
    assert_equal 311, export.row_count
    assert_equal 300, screen_names(tier: "Warm").size
  end

  test "formula-like company names and messages are escaped in the file" do
    evil = Company.find_by!(name: "HotNew")
    evil.update!(name: "=cmd|' /C calc'!A0")
    evil.messages.find_by!(label: "curious_question").update!(body: "@SUM(1+1)")

    row = csv_of(run_export(tier: "Hot")).find { |r| r["Contact"] == "Ada Lovelace" && r["Company"].include?("cmd") }
    assert_equal "'=cmd|' /C calc'!A0", row["Company"]
    assert_equal "'@SUM(1+1)", row["Message variant 1"]

    cells = XlsxReader.cells(run_export(format: "xlsx", tier: "Hot").data)
    assert_empty cells.flatten.select(&:formula)
  end

  test "filename carries the tier and date, and a failure is recorded instead of raised" do
    assert_equal "montani-leads-hot-#{Date.current.iso8601}.csv", run_export(tier: "Hot").filename
    assert_equal "montani-leads-all-#{Date.current.iso8601}.xlsx", run_export(format: "xlsx", scope: "all").filename

    broken = Exports::Runner.new(row: Object.new)
    export = Export.create!(file_format: "csv", scope: "all")
    broken.call(export)
    assert export.reload.failed?
    assert_includes export.error, "NoMethodError"
    assert_nil export.data
  end
end
