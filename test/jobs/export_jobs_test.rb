require "test_helper"

class ExportJobsTest < ActiveJob::TestCase
  include LeadsTestHelper

  test "ExportJob builds the file" do
    lead(name: "Alpha")
    export = Export.create!(file_format: "csv", scope: "all")
    ExportJob.perform_now(export.id)
    assert export.reload.done?
    assert_equal 1, export.row_count
  end

  test "ExportJob ignores an export deleted in the meantime" do
    assert_nothing_raised { ExportJob.perform_now(0) }
  end

  test "cleanup removes only exports older than the keep window" do
    old = Export.create!(file_format: "csv", scope: "all", created_at: 8.days.ago)
    fresh = Export.create!(file_format: "csv", scope: "all", created_at: 6.days.ago)
    CleanupExportsJob.perform_now
    assert_not Export.exists?(old.id)
    assert Export.exists?(fresh.id)
  end
end
