require "application_system_test_case"

class OutreachFlowTest < ApplicationSystemTestCase
  include OutreachTestHelper

  setup { @company = lead(name: "Acme", staffing: 9) }

  # The plan's "done when": a send can be logged in under 15 seconds.
  test "a whole send is logged in a few clicks, well inside 15 seconds" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    visit lead_path(@company)
    click_button "Mark connection sent"
    assert_button "Mark message sent"
    click_button "Mark message sent"
    assert_text "Message sent"
    select "Interested", from: "Reply result"
    assert_selector ".card-meta", text: "Interested"
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    record = @company.reload.outreach_send
    assert_equal [ true, true, true, true ], [ record.messaged?, record.replied, record.positive_reply, record.connection_accepted ]
    assert_operator elapsed, :<, 15, "logging a send took #{elapsed.round(1)}s"
  end

  test "the exact text on screen is recorded, even when edited and sent in the same second" do
    Outreach::Tracker.new.connection_sent!(@company)
    visit lead_path(@company)
    assigned = find(:xpath, "//form[.//span[@class='tag' and normalize-space()='Assigned to send']]")
    assigned.find("textarea").set("Hi Ada, typed a moment ago?")
    click_button "Mark message sent" # no waiting for autosave

    assert_text "Message sent"
    assert_equal "Hi Ada, typed a moment ago?", @company.reload.outreach_send.sent_body
  end

  test "the assigned variant is marked on its card and can be changed to another" do
    Outreach::Tracker.new.connection_sent!(@company)
    visit lead_path(@company)
    assert_selector ".tag", text: /assigned to send/i, count: 1

    other = (Message::LABELS - [ @company.outreach_send.variant ]).first
    select Message::LABEL_NAMES[other], from: "Use a different variant"

    assert_text "picked by you"
    assert_equal [ other, "manual" ], @company.reload.outreach_send.slice(:variant, :assignment).values
  end

  test "a reply before the message is marked sent is refused with a clear message" do
    Outreach::Tracker.new.connection_sent!(@company)
    visit lead_path(@company)
    select "Replied", from: "Reply result"

    assert_text "Mark the message as sent first"
    assert_nil @company.reload.reply_result
  end

  test "undo works step by step and a recorded reply locks the sent message" do
    visit lead_path(@company)
    click_button "Mark connection sent"
    click_button "Mark message sent"
    assert_text "Message sent"
    select "Replied", from: "Reply result"
    assert_selector ".card-meta", text: "Replied"
    assert_button "Undo message sent", disabled: true

    select "Not recorded", from: "Reply result"
    click_button "Undo message sent"
    assert_button "Mark message sent"
    click_button "Undo connection sent"
    assert_button "Mark connection sent"
    assert_nil @company.reload.outreach_send
  end

  test "the Results page shows what was logged, with the count behind each figure" do
    visit lead_path(@company)
    click_button "Mark connection sent"
    click_button "Mark message sent"
    select "Interested", from: "Reply result"
    assert_selector ".card-meta", text: "Interested"

    visit results_path
    within("#funnel-heading + table") do
      assert_text "Message sent"
      assert_text "1 of 1 too few to judge"
    end
    assert_text "Suggestions appear after 30 messages have been sent. So far: 1"
  end

  test "the outreach panel and results page fit a phone screen" do
    visit lead_path(@company)
    page.driver.browser.manage.window.resize_to(390, 900)
    click_button "Mark connection sent"
    assert_button "Mark message sent"
    assert_operator page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), :<=, 0
    visit results_path
    assert_operator page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), :<=, 0
  end
end
