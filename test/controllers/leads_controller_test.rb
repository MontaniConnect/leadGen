require "test_helper"

class LeadsControllerTest < ActionDispatch::IntegrationTest
  include LeadsTestHelper

  test "the home page is the queue with the best Hot lead selected" do
    lead(name: "Second", staffing: 6, automation: 6)
    lead(name: "First", staffing: 9, automation: 5)
    get root_path

    assert_response :success
    assert_select "h1", text: "Hot leads (2)"
    assert_select ".cards li:first-child .card-name", text: "First"
    assert_select ".cards li:first-child a[aria-current=page]"
    assert_select ".detail h1", text: "First"
  end

  test "queue cards show tier text, both scores and status" do
    lead(name: "Acme", staffing: 7, automation: 8)
    get root_path
    assert_select ".card-link .badge", text: "Hot"
    assert_select ".card-meta", text: "Staffing 7 · Automation 8"
    assert_select ".card-meta", text: "To contact"
  end

  test "filter chips mark the current filter with aria-current and switch tiers" do
    lead(name: "HotCo")
    lead(name: "WarmCo", tier: "Warm")
    get leads_path(tier: "Warm")

    assert_select "a.filter[aria-current=true]", text: "Warm"
    assert_select ".card-name", text: "WarmCo"
    assert_select ".card-name", text: "HotCo", count: 0
  end

  test "To contact chip hides contacted leads" do
    lead(name: "Fresh")
    lead(name: "Sent", connection_sent_at: Time.current)
    get leads_path(status: "to_contact")

    assert_select "a.filter[aria-current=true]", text: "To contact"
    assert_select ".card-name", text: "Fresh"
    assert_select ".card-name", text: "Sent", count: 0
  end

  test "lead detail shows header, scores, why now, signals with source chips and red flags" do
    company = lead(name: "Acme", staffing: 7, automation: 8)
    get lead_path(company)

    assert_select ".lead-title h1", text: "Acme"
    assert_select ".lead-title .badge", text: "Hot"
    assert_select ".pill", text: "Confidence: Medium"
    assert_select ".site-link[href='https://www.acme.com'][rel='noopener noreferrer'][target=_blank]"
    assert_select ".score-card", text: /Staffing fit\s*7\/10/
    assert_select ".score-card", text: /Automation fit\s*8\/10/
    assert_select "#why-now-heading + p", text: "Raised Series A in October"
    assert_select ".chip", text: "Source: Apollo"
    assert_select "a.chip[href='https://acme.com/careers'][rel='noopener noreferrer']", text: "Source: /careers"
    assert_select ".panel.flags li p", text: "Handles patient data"
  end

  test "contact card link falls back: profile, then company page, then plain text" do
    with_profile = lead(name: "One", linkedin_url: "https://linkedin.com/company/one")
    get lead_path(with_profile)
    assert_select "a.btn[href='https://www.linkedin.com/in/ada']", text: "Open LinkedIn profile"

    with_profile.selected_contact.update!(linkedin_url: nil)
    get lead_path(with_profile)
    assert_select "a.btn[href='https://linkedin.com/company/one']", text: "Company page (no contact found)"

    with_profile.update!(linkedin_url: nil)
    get lead_path(with_profile)
    assert_select "a.btn", count: 0
    assert_select ".none-text", text: "No LinkedIn link"
  end

  test "external links open safely and unsafe source URLs are not linked" do
    company = lead(name: "Acme")
    company.current_evaluation.update!(signals: [ { "signal" => "x", "source" => "javascript:alert(1)" } ])
    get lead_path(company)

    assert_select "a[target=_blank]:not([rel~=noopener])", count: 0
    assert_select "a[href^='javascript']", count: 0
    assert_select ".chip", text: "Source: javascript:alert(1)"
  end

  test "three message variants in order with editable text and word counts" do
    get lead_path(lead(name: "Acme"))

    assert_select "h3 label", count: 3
    assert_select "h3 label" do |labels|
      assert_equal [ "Curious question", "Founder-time angle", "Low-pressure offer" ], labels.map { |l| l.text.strip }
    end
    assert_select "textarea.message-field", count: 3
    assert_select "textarea.message-field", text: /I'm curious how you split support/
    assert_select ".word-count", text: /\d+ words/, count: 3
    assert_select "button[data-first-copy]", count: 1
    assert_select "button", text: "Copy message", count: 3
  end

  test "a message over 50 words shows a visible warning, others keep it hidden" do
    company = lead(name: "Acme")
    company.messages.find_by!(label: "founder_time").update!(body: "word " * 60)
    get lead_path(company)

    assert_select ".warning:not([hidden])", text: /Over 50 words/, count: 1
    assert_select ".warning[hidden]", count: 2
    assert_select ".word-count.over", text: "60 words"
  end

  test "the outreach panel walks through the steps with labelled controls" do
    company = lead(name: "Acme")
    get lead_path(company)
    assert_select "#outreach-heading", text: "Outreach"
    assert_select "button#outreach-next", text: "Mark connection sent"
    assert_select "label[for=reply_result]", text: "Reply result"
    assert_select "select#reply_result option", count: 6
    assert_select "select#reply_result option", text: "Call booked"
  end

  test "the queue card status follows the outreach: To contact, Connection sent, Message sent, then the reply" do
    company = lead(name: "Acme")
    status = -> { get root_path; css_select(".card-meta").map { |node| node.text.strip }.last }
    assert_equal "To contact", status.call

    send_record = Outreach::Tracker.new.connection_sent!(company)
    assert_equal "Connection sent", status.call
    Outreach::Tracker.new.message_sent!(send_record)
    assert_equal "Message sent", status.call
    Outreach::ReplyRecorder.new.call(company, "interested")
    assert_equal "Interested", status.call
  end

  test "J/K neighbours are wired into the page" do
    a = lead(name: "Aaa", staffing: 9)
    b = lead(name: "Bbb", staffing: 8)
    get lead_path(a)
    assert_select "[data-shortcuts-next-url-value='#{lead_path(b, tier: 'Hot')}']"
    assert_select "[data-shortcuts-previous-url-value='']"
  end

  test "an empty queue shows a friendly message, not an error" do
    get root_path
    assert_response :success
    assert_select ".empty", text: /Nothing to review/
  end

  test "every control has a name: buttons, links, select and textareas" do
    get lead_path(lead(name: "Acme"))
    css_select("button, a.btn").each do |control|
      assert control.text.strip.present? || control["aria-label"].present?, "unnamed control: #{control}"
    end
    css_select("textarea").each do |area|
      assert_equal 1, css_select("label[for='#{area['id']}']").size, "textarea #{area['id']} has no label"
    end
  end
end
