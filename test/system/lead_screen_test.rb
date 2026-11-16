require "application_system_test_case"

class LeadScreenTest < ApplicationSystemTestCase
  include LeadsTestHelper

  test "Copy copies the current edited text, shows Copied, then resets after about two seconds" do
    company = lead(name: "Acme")
    visit lead_path(company)
    stub_clipboard

    field = find("textarea", match: :first)
    field.set("Hi Ada, my edited version of this note?")
    button = first("button", text: "Copy message")
    button.click

    assert_button "Copied"
    assert_equal [ "Hi Ada, my edited version of this note?" ], copied_texts
    assert_button "Copy message", count: 3, wait: 4 # back to normal after ~2s
  end

  test "each variant copies its own text" do
    visit lead_path(lead(name: "Acme"))
    stub_clipboard
    all("button", text: "Copy message")[2].click

    assert_includes copied_texts.first, "careers page lists a Salesforce admin role"
  end

  test "word count updates live and the over-50 warning appears and disappears" do
    visit lead_path(lead(name: "Acme"))
    field = find("textarea", match: :first)
    warning = "Over 50 words"

    field.set("word " * 60)
    assert_text warning
    assert_text "60 words"
    field.set("Hi Ada, short?")
    assert_no_text warning
    assert_text "3 words"
  end

  test "edits autosave on blur and survive a reload" do
    company = lead(name: "Acme")
    visit lead_path(company)
    find("textarea", match: :first).set("Hi Ada, saved by blur?")
    find("h1", match: :first).click # blur

    assert_text "Saved"
    visit current_path
    assert_equal "Hi Ada, saved by blur?", find("textarea", match: :first).value
  end

  test "keyboard shortcuts: C copies the first message, S advances the outreach, J moves to the next lead" do
    first_lead = lead(name: "Aaa", staffing: 9)
    lead(name: "Bbb", staffing: 8)
    visit lead_path(first_lead)
    stub_clipboard

    send_keys "c"
    assert_button "Copied"
    assert_includes copied_texts.first, "I'm curious how you split support"

    send_keys "s"
    assert_button "Mark message sent"      # connection recorded, next step offered
    send_keys "s"
    assert_text "Message sent"             # message recorded
    assert_not_nil first_lead.reload.outreach_send.sent_at

    send_keys "j"
    assert_selector ".lead-title h1", text: "Bbb"
  end

  test "shortcuts are ignored while typing in a message" do
    visit lead_path(lead(name: "Acme"))
    find("textarea", match: :first).send_keys("jks")

    assert_selector ".lead-title h1", text: "Acme"
    assert_button "Mark connection sent"   # S typed in a message box did nothing
  end

  test "the reply select saves on change" do
    company = lead(name: "Acme")
    visit lead_path(company)
    select "Interested", from: "Reply result"

    assert_selector ".card-meta", text: "Interested"
    assert_equal "interested", company.reload.reply_result
  end

  test "the LinkedIn control follows the fallback order on screen" do
    company = lead(name: "Acme", linkedin_url: "https://linkedin.com/company/acme")
    visit lead_path(company)
    assert_link "Open LinkedIn profile", href: "https://www.linkedin.com/in/ada"

    company.selected_contact.update!(linkedin_url: nil)
    visit lead_path(company)
    assert_link "Company page (no contact found)", href: "https://linkedin.com/company/acme"

    company.update!(linkedin_url: nil)
    visit lead_path(company)
    assert_text "No LinkedIn link"
    assert_no_link "No LinkedIn link"
  end

  test "controls meet the 44px touch target size" do
    visit lead_path(lead(name: "Acme"))
    sizes = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".detail button, .detail select, .detail a.btn, .filter, .card-link"))
        .map(el => ({ name: (el.textContent || el.id).trim().slice(0, 30), h: el.getBoundingClientRect().height }))
    JS
    small = sizes.select { |s| s["h"] < 44 }
    assert_empty small, "Controls under 44px: #{small}"
  end

  test "the page does not scroll sideways at phone width" do
    visit lead_path(lead(name: "Acme"))
    page.driver.browser.manage.window.resize_to(390, 900)
    overflow = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    assert_operator overflow, :<=, 0
  end
end
