require "test_helper"

class Exports::RepliesImporterTest < ActiveSupport::TestCase
  include LeadsTestHelper

  setup do
    @a = lead(name: "Alpha", apollo_account_id: "a1")
    @b = lead(name: "Bravo", apollo_account_id: "b2")
    @c = lead(name: "Charlie", apollo_account_id: "c3", reply_result: "interested")
  end

  def import(csv)
    file = Tempfile.new([ "replies", ".csv" ])
    file.write(csv)
    file.close
    Exports::RepliesImporter.new(file.path).call
  end

  test "updates reply results matched on Apollo Account Id, from labels or keys" do
    batch = import(<<~CSV)
      Company,Apollo Account Id,Reply Result
      Alpha,a1,Replied
      Bravo,b2,not_a_fit
    CSV

    assert_equal 2, batch.rows_updated
    assert_equal "replied", @a.reload.reply_result
    assert_equal "not_a_fit", @b.reload.reply_result
    assert_equal "replies", batch.kind
  end

  test "label matching ignores case, spaces and punctuation" do
    import("Apollo Account Id,Reply Result\na1,  no REPLY \nb2,Not-A-Fit\n")
    assert_equal [ "no_reply", "not_a_fit" ], [ @a.reload.reply_result, @b.reload.reply_result ]
  end

  test "blank reply cells change nothing and never clear an existing result" do
    batch = import("Apollo Account Id,Reply Result\nc3,\n")
    assert_equal "interested", @c.reload.reply_result
    assert_equal({ "blank_reply_result" => 1 }, batch.skip_reasons)
  end

  test "bad rows are skipped with reasons and the rest still import" do
    batch = import(<<~CSV)
      Apollo Account Id,Reply Result
      a1,Replied
      ghost,Replied
      b2,maybe
      ,Replied
    CSV

    assert_equal 1, batch.rows_updated
    assert_equal({ "unknown_company" => 1, "invalid_reply_result" => 1, "missing_apollo_account_id" => 1 }, batch.skip_reasons)
  end

  test "re-importing the same file changes nothing" do
    csv = "Apollo Account Id,Reply Result\na1,Replied\n"
    import(csv)
    second = import(csv)
    assert_equal 0, second.rows_updated
    assert_equal 1, second.rows_unchanged
  end

  test "round trip: export, edit the Reply Result column in a sheet, import" do
    export = Export.create!(file_format: "csv", scope: "all")
    Exports::Runner.new.call(export)
    sheet = CSV.parse(export.data.dup.force_encoding("UTF-8").delete_prefix("\uFEFF"), headers: true)
    edited = CSV.generate do |csv|
      csv << sheet.headers
      sheet.each do |row|
        row["Reply Result"] = "Interested" if row["Company"] == "Alpha"
        row["Reply Result"] = "No reply" if row["Company"] == "Bravo"
        csv << row.fields
      end
    end

    import(edited)

    assert_equal "interested", @a.reload.reply_result
    assert_equal "no_reply", @b.reload.reply_result
    assert_equal "interested", @c.reload.reply_result, "its exported value 'Interested' re-imports unchanged"
  end

  test "Call booked is accepted as a label and sets every flag on a messaged send" do
    send_record = Outreach::Tracker.new.connection_sent!(@a)
    Outreach::Tracker.new.message_sent!(send_record)
    batch = import("Apollo Account Id,Reply Result\na1,Call booked\n")

    assert_equal 1, batch.rows_updated
    assert_equal "call_booked", @a.reload.reply_result
    assert_equal [ true, true, true ], [ send_record.reload.replied, send_record.positive_reply, send_record.call_booked ]
    assert_empty batch.notes
  end

  test "a reply for a lead whose message was never marked sent is skipped, not half-recorded" do
    send_record = Outreach::Tracker.new.connection_sent!(@a)
    batch = import("Apollo Account Id,Reply Result\na1,Replied\n")

    assert_equal({ "message_not_marked_sent" => 1 }, batch.skip_reasons)
    assert_nil @a.reload.reply_result
    assert_not send_record.reload.replied
  end

  test "a reply for a lead with no logged send updates the lead and says so" do
    batch = import("Apollo Account Id,Reply Result\nb2,Interested\n")

    assert_equal 1, batch.rows_updated
    assert_equal({ "recorded_without_a_send_record" => 1 }, batch.notes)
    assert_includes Imports::Summary.new(batch).to_s, "note: recorded_without_a_send_record: 1"
  end
end
