require "test_helper"

class OutreachSendTest < ActiveSupport::TestCase
  include OutreachTestHelper

  def build(**attrs)
    OutreachSend.new({ company: Company.create!(name: "A#{SecureRandom.hex(3)}"), connection_sent_at: Time.current }.merge(attrs))
  end

  test "flags stay consistent: a booked call is positive, a positive is a reply, a reply means accepted" do
    record = build(call_booked: true)
    record.save!
    assert_equal [ true, true, true, true ], [ record.call_booked, record.positive_reply, record.replied, record.connection_accepted ]
    assert_not_nil record.replied_at
  end

  test "no reply means no reply time" do
    record = build(replied: false, replied_at: Time.current)
    record.save!
    assert_nil record.replied_at
  end

  test "reply results map to flags: replied, interested, call booked, not a fit, no reply" do
    record = build(sent_at: Time.current, sent_body: "Hi?", variant: "curious_question")
    record.save!
    {
      "replied" => [ true, false, false ], "interested" => [ true, true, false ], "call_booked" => [ true, true, true ],
      "not_a_fit" => [ true, false, false ], "no_reply" => [ false, false, false ]
    }.each do |result, expected|
      record.record_reply_result!(result)
      assert_equal expected, [ record.replied, record.positive_reply, record.call_booked ], result
    end
  end

  test "a blank result clears every reply flag and the reply time" do
    record = build(sent_at: Time.current, sent_body: "Hi?", variant: "curious_question")
    record.save!
    record.record_reply_result!("interested")
    record.record_reply_result!("")
    assert_equal [ false, false, false, nil ], [ record.replied, record.positive_reply, record.call_booked, record.replied_at ]
  end

  test "the first reply time is kept when the result is refined later" do
    record = build(sent_at: Time.current, sent_body: "Hi?", variant: "curious_question")
    record.save!
    first = 5.days.ago.change(usec: 0)
    record.record_reply_result!("replied", at: first)
    record.record_reply_result!("interested", at: Time.current)
    assert_equal first, record.replied_at
  end

  test "reply_result reduces the flags back to the key shown on screen" do
    assert_nil build.reply_result
    assert_equal "replied", build(replied: true).reply_result
    assert_equal "interested", build(positive_reply: true).reply_result
    assert_equal "call_booked", build(call_booked: true).reply_result
  end

  test "a sent message needs a variant and the exact text, and its word count is computed" do
    assert_not build(sent_at: Time.current).valid?
    assert_not build(sent_at: Time.current, variant: "curious_question").valid?
    record = build(sent_at: Time.current, variant: "curious_question", sent_body: "Hi Ada, quick one for you today?")
    assert record.valid?
    assert_equal 7, record.tap(&:valid?).word_count
  end

  test "variant and assignment must be known values, and a lead has at most one send" do
    assert_not build(variant: "made_up").valid?
    assert_not build(assignment: "coin_toss").valid?
    first = build
    first.save!
    duplicate = OutreachSend.new(company: first.company, connection_sent_at: Time.current)
    assert_not duplicate.valid?
  end
end
