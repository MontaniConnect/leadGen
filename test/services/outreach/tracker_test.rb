require "test_helper"

class Outreach::TrackerTest < ActiveSupport::TestCase
  include OutreachTestHelper

  # Always picks the same variant, so lifecycle tests don't depend on randomness.
  FixedAssigner = Struct.new(:variant, :assignment) do
    def call(labels:, segments:) = Outreach::Assignment.new(labels.include?(variant) ? variant : labels.first, assignment)
  end

  setup do
    @company = lead(name: "Acme")
    @company.update!(industry: "Software", employees: 42)
    @tracker = Outreach::Tracker.new(assigner: FixedAssigner.new("curious_question", "random"))
  end

  test "connection sent: creates the send, assigns a variant, snapshots the lead and updates the company" do
    send_record = @tracker.connection_sent!(@company)

    assert_equal [ "curious_question", "random", @company.selected_contact ], [ send_record.variant, send_record.assignment, send_record.contact ]
    assert_equal @company.messages.find_by!(label: "curious_question"), send_record.message
    assert_equal [ "Hot", 8, 6, "Medium", "Software", 42, "CEO" ],
                 send_record.slice(:tier, :staffing_score, :automation_score, :confidence, :industry, :employee_count, :contact_title).values
    assert send_record.had_why_now
    assert_not send_record.messaged?
    assert_not_nil @company.reload.connection_sent_at
    assert_equal "Connection sent", @company.lead_status
  end

  test "the snapshot does not change when the lead is re-scored afterwards" do
    send_record = @tracker.connection_sent!(@company)
    @company.evaluations.create!(status: "ok", tier: "Cold", staffing_score: 1, automation_score: 1, confidence: "Low")
    assert_equal [ "Hot", 8 ], send_record.reload.slice(:tier, :staffing_score).values
  end

  test "an unscored lead and a second send are refused" do
    assert_raises(Outreach::Tracker::Rejected) { @tracker.connection_sent!(Company.create!(name: "Unscored")) }
    @tracker.connection_sent!(@company)
    assert_raises(Outreach::Tracker::Rejected) { @tracker.connection_sent!(@company.reload) }
  end

  test "message sent stores the exact text sent, not the draft, and marks the draft sent" do
    send_record = @tracker.connection_sent!(@company)
    message = send_record.message
    original = message.body

    @tracker.message_sent!(send_record, body: "  Hi Ada, my last-second edit before sending?  ")

    assert_equal "Hi Ada, my last-second edit before sending?", send_record.sent_body
    assert_equal 7, send_record.word_count
    assert send_record.messaged?
    assert send_record.connection_accepted, "a message can only go out after the connection is accepted"
    assert_equal "sent", message.reload.status
    assert_equal original, message.body, "the saved draft is untouched"
    assert_equal "Message sent", @company.reload.lead_status
  end

  test "without a typed body it records the saved draft text" do
    send_record = @tracker.connection_sent!(@company)
    @tracker.message_sent!(send_record)
    assert_equal send_record.message.body, send_record.sent_body
  end

  test "accepted can be toggled until the message is sent" do
    send_record = @tracker.connection_sent!(@company)
    assert @tracker.toggle_accepted!(send_record).connection_accepted
    assert_not @tracker.toggle_accepted!(send_record).connection_accepted
    @tracker.message_sent!(send_record)
    assert_raises(Outreach::Tracker::Rejected) { @tracker.toggle_accepted!(send_record) }
  end

  test "changing the variant is manual, only to a draft the lead has, and only before sending" do
    send_record = @tracker.connection_sent!(@company)
    @tracker.change_variant!(send_record, "low_pressure_offer")
    assert_equal [ "low_pressure_offer", "manual" ], [ send_record.variant, send_record.assignment ]
    assert_equal "low_pressure_offer", send_record.message.label

    @company.messages.find_by!(label: "founder_time").destroy
    assert_raises(Outreach::Tracker::Rejected) { @tracker.change_variant!(send_record, "founder_time") }
    @tracker.message_sent!(send_record)
    assert_raises(Outreach::Tracker::Rejected) { @tracker.change_variant!(send_record, "curious_question") }
  end

  test "undo message sent clears the text; undo connection removes the send; neither once a reply exists" do
    send_record = @tracker.connection_sent!(@company)
    @tracker.message_sent!(send_record, body: "Hi Ada, sent?")
    assert_raises(Outreach::Tracker::Rejected) { @tracker.undo_connection!(send_record) }

    @tracker.undo_message!(send_record)
    assert_nil send_record.sent_at
    assert_nil send_record.sent_body
    assert_equal "edited", send_record.message.reload.status

    @tracker.message_sent!(send_record, body: "Hi Ada, sent again?")
    send_record.record_reply_result!("replied")
    assert_raises(Outreach::Tracker::Rejected) { @tracker.undo_message!(send_record) }

    send_record.record_reply_result!("")
    @tracker.undo_message!(send_record)
    @tracker.undo_connection!(send_record)
    assert_nil @company.reload.outreach_send
    assert_nil @company.connection_sent_at
  end

  test "a lead with no drafts can still have its connection recorded, with no variant" do
    bare = lead(name: "Bare", drafted: false)
    send_record = Outreach::Tracker.new.connection_sent!(bare)
    assert_nil send_record.variant
    assert_equal "manual", send_record.assignment
    assert_raises(Outreach::Tracker::Rejected) { Outreach::Tracker.new.message_sent!(send_record) }
  end

  test "reply recorder updates the lead and its send together, and refuses before the message is sent" do
    send_record = @tracker.connection_sent!(@company)
    assert_raises(Outreach::ReplyRecorder::NotMessaged) { Outreach::ReplyRecorder.new.call(@company, "replied") }
    assert_nil @company.reload.reply_result
    assert_not send_record.reload.replied

    @tracker.message_sent!(send_record)
    outcome = Outreach::ReplyRecorder.new.call(@company, "call_booked")
    assert_equal "call_booked", @company.reload.reply_result
    assert_equal [ true, true, true ], send_record.reload.then { |r| [ r.replied, r.positive_reply, r.call_booked ] }
    assert_equal send_record, outcome.send_record

    Outreach::ReplyRecorder.new.call(@company, "")
    assert_nil @company.reload.reply_result
    assert_equal [ false, false, false ], send_record.reload.then { |r| [ r.replied, r.positive_reply, r.call_booked ] }
  end

  test "a reply for a lead with no send is recorded on the lead only" do
    other = lead(name: "Other")
    outcome = Outreach::ReplyRecorder.new.call(other, "interested")
    assert_equal "interested", other.reload.reply_result
    assert_nil outcome.send_record
  end
end
