require "test_helper"

class OutreachesControllerTest < ActionDispatch::IntegrationTest
  include OutreachTestHelper

  setup do
    @company = lead(name: "Acme")
    @company.update!(industry: "Software", employees: 42)
  end

  def send_record = @company.reload.outreach_send

  test "marking the connection sent creates the send, assigns a variant and shows the next step" do
    post lead_outreach_path(@company, tier: "Hot")

    assert_redirected_to lead_path(@company, tier: "Hot")
    assert_includes Message::LABELS, send_record.variant
    assert_equal "random", send_record.assignment
    follow_redirect!
    assert_select "p", text: /Message to send:.*assigned at random/m
    assert_select "input#outreach-next[value='Mark message sent']"
    assert_select "button", text: "Undo connection sent"
    assert_select ".tag", text: "Assigned to send", count: 1
  end

  test "marking the message sent records the exact text sent, even if it differs from the saved draft" do
    post lead_outreach_path(@company)
    message = send_record.message
    post message_sent_lead_outreach_path(@company), params: { sent_body: "Hi Ada, edited at the last second?" }

    assert_equal "Hi Ada, edited at the last second?", send_record.sent_body
    assert_not_equal message.reload.body, send_record.sent_body
    assert send_record.messaged?
    follow_redirect!
    assert_select "p", text: /Message sent .*#{Message::LABEL_NAMES[send_record.variant]}.*7 words/m
    assert_select ".tag.sent", text: "Sent"
  end

  test "the exact text and its word count are what the Results page later reports" do
    post lead_outreach_path(@company)
    post message_sent_lead_outreach_path(@company), params: { sent_body: "Hi Ada, this one is exactly eight words long?" }
    assert_equal 9, send_record.word_count
  end

  test "reply results update the lead and the send; refused before the message is sent" do
    post lead_outreach_path(@company)
    patch reply_lead_outreach_path(@company), params: { reply_result: "replied" }
    assert_match(/Mark the message as sent first/, flash[:alert])
    assert_nil @company.reload.reply_result

    post message_sent_lead_outreach_path(@company)
    { "interested" => [ true, true, false ], "call_booked" => [ true, true, true ], "no_reply" => [ false, false, false ] }.each do |result, flags|
      patch reply_lead_outreach_path(@company), params: { reply_result: result }
      assert_equal result, @company.reload.reply_result
      assert_equal flags, [ send_record.replied, send_record.positive_reply, send_record.call_booked ]
    end
    assert_nil send_record.replied_at, "no reply means no reply time"
  end

  test "an unknown reply result is refused" do
    patch reply_lead_outreach_path(@company), params: { reply_result: "bogus" }
    assert_equal "Unknown reply result.", flash[:alert]
    assert_nil @company.reload.reply_result
  end

  test "a reply can be logged for a lead with no send record (the lead only)" do
    patch reply_lead_outreach_path(@company), params: { reply_result: "interested" }
    assert_redirected_to lead_path(@company, tier: "Hot")
    assert_equal "interested", @company.reload.reply_result
    assert_nil send_record
  end

  test "choosing a different variant makes the assignment manual" do
    post lead_outreach_path(@company)
    other = (Message::LABELS - [ send_record.variant ]).first
    patch variant_lead_outreach_path(@company), params: { variant: other }

    assert_equal [ other, "manual" ], [ send_record.variant, send_record.assignment ]
    follow_redirect!
    assert_select "label[for=variant]", text: "Use a different variant"
    assert_select "p", text: /picked by you/
  end

  test "accepted toggles, and undo steps reverse their step" do
    post lead_outreach_path(@company)
    patch accepted_lead_outreach_path(@company)
    assert send_record.connection_accepted
    patch accepted_lead_outreach_path(@company)
    assert_not send_record.connection_accepted

    post message_sent_lead_outreach_path(@company)
    delete message_sent_lead_outreach_path(@company)
    assert_not send_record.messaged?
    delete lead_outreach_path(@company)
    assert_nil send_record
    assert_nil @company.reload.connection_sent_at
  end

  test "steps out of order are refused with a message, not an error page" do
    patch accepted_lead_outreach_path(@company)
    assert_equal "Mark the connection request sent first.", flash[:alert]
    post message_sent_lead_outreach_path(@company)
    assert_equal "Mark the connection request sent first.", flash[:alert]

    post lead_outreach_path(@company)
    post lead_outreach_path(@company)
    assert_match(/already recorded/, flash[:alert])
    post message_sent_lead_outreach_path(@company)
    delete lead_outreach_path(@company)
    assert_match(/Undo the sent message first/, flash[:alert])
    assert_not_nil send_record, "the recorded message was not lost"
  end

  test "a lead with no drafts cannot have a message marked sent" do
    bare = lead(name: "Bare", drafted: false)
    post lead_outreach_path(bare)
    post message_sent_lead_outreach_path(bare)
    assert_match(/no drafted message/, flash[:alert])
  end

  test "the queue filters are kept across every step" do
    post lead_outreach_path(@company, tier: "Hot", status: "to_contact")
    assert_redirected_to lead_path(@company, tier: "Hot", status: "to_contact")
    patch reply_lead_outreach_path(@company, tier: "Warm"), params: { reply_result: "" }
    assert_redirected_to lead_path(@company, tier: "Warm")
  end

  test "the screen with a send in progress has real names on every control" do
    post lead_outreach_path(@company)
    get lead_path(@company)
    css_select("button, input[type=submit]").each do |control|
      name = control.text.strip.presence || control["value"].presence || control["aria-label"]
      assert name.present?, "unnamed control: #{control}"
    end
  end
end
