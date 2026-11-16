require "test_helper"

class ExportsControllerTest < ActionDispatch::IntegrationTest
  include LeadsTestHelper

  setup do
    lead(name: "Alpha", staffing: 9, apollo_account_id: "a1")
    lead(name: "Bravo", staffing: 8, connection_sent_at: Time.current, apollo_account_id: "b2")
  end

  def csv_of(response_body) = CSV.parse(response_body.dup.force_encoding("UTF-8").delete_prefix("﻿"), headers: true)

  test "a small export is built immediately and downloads as the current view" do
    post exports_path, params: { file_format: "csv", scope: "view", tier: "Hot", status: "to_contact" }
    export = Export.last
    assert_redirected_to export_path(export)
    assert export.done?

    follow_redirect!
    assert_select "a.btn[href='#{download_export_path(export)}']", text: "Download CSV"

    get download_export_path(export)
    assert_response :success
    assert_match(/attachment; filename="?montani-leads-hot-/, response.headers["Content-Disposition"])
    assert_includes response.media_type, "text/csv"
    assert_equal [ "Alpha" ], csv_of(response.body).map { |row| row["Company"] }
  end

  test "XLSX downloads with the spreadsheet content type" do
    post exports_path, params: { file_format: "xlsx", scope: "all" }
    get download_export_path(Export.last)

    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_equal %w[Alpha Bravo], XlsxReader.rows(response.body).drop(1).map(&:first)
  end

  test "a large export runs as a background job and the page waits, then offers the download" do
    Setting.set("export.inline_row_limit", 1)
    assert_enqueued_with(job: ExportJob) do
      post exports_path, params: { file_format: "csv", scope: "view", tier: "Hot" }
    end
    export = Export.last
    assert_equal "pending", export.status

    get export_path(export)
    assert_select "meta[http-equiv=refresh]"
    assert_select "[role=status]", text: /Building your export/
    assert_select "a", text: /Download/, count: 0

    get download_export_path(export)
    assert_redirected_to export_path(export)

    perform_enqueued_jobs
    get export_path(export)
    assert_select "meta[http-equiv=refresh]", count: 0
    assert_select "a.btn", text: "Download CSV"
  end

  test "filters from the queue are carried into the export" do
    post exports_path, params: { file_format: "csv", scope: "view", tier: "Hot", status: "sent", bogus: "x", reply: "'; DROP TABLE" }
    export = Export.last
    assert_equal({ "tier" => "Hot", "status" => "sent" }, export.filters)
    assert_equal [ "Bravo" ], csv_of(export.data).map { |row| row["Company"] }
  end

  test "an empty view, a bad format and a bad scope are refused without creating an export" do
    assert_no_difference "Export.count" do
      post exports_path, params: { file_format: "csv", scope: "view", tier: "Warm" }
      assert_redirected_to leads_path(tier: "Warm")
      assert_equal "Nothing to export for this view.", flash[:alert]

      post exports_path, params: { file_format: "pdf", scope: "view", tier: "Hot" }
      assert_match(/Choose CSV or XLSX/, flash[:alert])

      post exports_path, params: { file_format: "csv", scope: "everything" }
      assert_match(/Choose CSV or XLSX/, flash[:alert])
    end
  end

  test "a failed export shows its error on the page" do
    export = Export.create!(file_format: "csv", scope: "all", status: "failed", error: "NoMethodError: boom")
    get export_path(export)
    assert_select "p", text: /The export failed/
    assert_select "meta[http-equiv=refresh]", count: 0
  end

  test "index lists recent exports and has the reply import form" do
    post exports_path, params: { file_format: "csv", scope: "all" }
    get exports_path

    assert_select "table td", text: "All scored leads"
    assert_select "form[action='#{import_replies_exports_path}'][enctype='multipart/form-data']"
    assert_select "label[for=file]", text: "CSV file"
  end

  test "uploading a reply sheet updates leads and shows the summary" do
    file = Rack::Test::UploadedFile.new(StringIO.new("Apollo Account Id,Reply Result\na1,Interested\nzz,Replied\n"),
                                        "text/csv", original_filename: "replies.csv")
    post import_replies_exports_path, params: { file: file }

    assert_redirected_to exports_path
    assert_equal "interested", Company.find_by!(apollo_account_id: "a1").reply_result
    assert_match(/updated:\s+1/, flash[:notice])
    assert_match(/unknown_company: 1/, flash[:notice])
    assert_equal "replies.csv", ImportBatch.last.filename
  end

  test "reply import refuses a missing file, a non-CSV file and unreadable CSV" do
    post import_replies_exports_path
    assert_equal "Choose a CSV file first.", flash[:alert]

    post import_replies_exports_path, params: { file: Rack::Test::UploadedFile.new(StringIO.new("x"), "text/plain", original_filename: "notes.txt") }
    assert_equal "Only .csv files can be imported.", flash[:alert]

    bad = Rack::Test::UploadedFile.new(StringIO.new("Apollo Account Id,Reply Result\n\"unterminated,x\n"), "text/csv", original_filename: "bad.csv")
    post import_replies_exports_path, params: { file: bad }
    assert_match(/could not be read/, flash[:alert])
  end

  test "the lead queue offers the export and filter controls with real labels" do
    get leads_path
    assert_select "details.more summary", text: "Export"
    assert_select "label[for=scope]", text: "What to export"
    assert_select "select#scope option", text: "Current view (2 leads)"
    assert_select "label[for=file_format]", text: "Format"
    assert_select "label[for=status]", text: "Status"
    assert_select "label[for=reply]", text: "Reply result"
    assert_select "label[for=batch]", text: "Import batch"
  end

  test "the filter form keeps the tier and marks active extra filters open" do
    get leads_path(tier: "Hot", status: "sent")
    assert_select "details.more[open] summary", text: "More filters"
    assert_select "select#status option[selected]", text: "Connection sent"
    assert_select ".card-name", text: "Bravo"
    assert_select ".card-name", text: "Alpha", count: 0
  end
end
