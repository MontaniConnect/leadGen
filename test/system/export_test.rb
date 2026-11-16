require "application_system_test_case"

class ExportTest < ApplicationSystemTestCase
  include LeadsTestHelper

  setup do
    lead(name: "Alpha", staffing: 9)
    lead(name: "Bravo", staffing: 8, connection_sent_at: Time.current)
  end

  test "exporting the current view from the queue ends on a download link" do
    visit leads_path
    find("summary", text: "Export").click
    select "XLSX (Excel)", from: "Format"
    click_button "Export"

    assert_text "Ready."
    assert_text "2 leads"
    assert_link "Download XLSX"
  end

  test "an export of a filtered view counts only the filtered leads" do
    visit leads_path
    find("summary", text: "More filters").click
    select "To contact", from: "Status"
    click_button "Apply filters"
    assert_selector ".card-name", text: "Alpha"
    assert_no_selector ".card-name", text: "Bravo"

    find("summary", text: "Export").click
    assert_selector "option", text: "Current view (1 lead)"
    click_button "Export"
    assert_text "1 lead in montani-leads-hot-"
  end

  test "the export and filter controls fit a phone screen without sideways scrolling" do
    visit leads_path
    page.driver.browser.manage.window.resize_to(390, 900)
    find("summary", text: "Export").click
    overflow = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    assert_operator overflow, :<=, 0
  end
end
