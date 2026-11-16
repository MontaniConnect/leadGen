require "application_system_test_case"

class ImportFlowTest < ApplicationSystemTestCase
  ACCOUNTS = Rails.root.join("test/fixtures/files/accounts.csv").to_s
  PEOPLE = Rails.root.join("test/fixtures/files/people.csv").to_s
  PILOT = Rails.root.join("test/fixtures/files/pilot_accounts.csv").to_s

  test "from the empty app, upload the accounts file and land on the Pass/Fail decisions" do
    visit root_path
    click_link "Import your Apollo file"
    attach_file "Apollo accounts CSV", ACCOUNTS
    choose "All rows"
    click_button "Import accounts"

    assert_text "Imported accounts.csv: 6 rows read, 3 new"
    assert_text "Prefilter: 1 pass, 2 fail."
    assert_current_path dashboard_path
    assert_text "employees_above_max"
  end

  test "the default is a 20-row sample, so the first import is the pilot" do
    visit new_import_path
    assert_checked_field "A random sample first (recommended)", visible: :all
    attach_file "Apollo accounts CSV", PILOT
    click_button "Import accounts"

    assert_text "20 rows read, 20 new"
    assert_equal 20, Company.count
  end

  test "then the people file, and the wrong file gives a readable explanation" do
    visit new_import_path
    attach_file "Apollo accounts CSV", ACCOUNTS
    choose "All rows"
    click_button "Import accounts"
    assert_text "Prefilter"

    visit new_import_path
    attach_file "Apollo people CSV", PEOPLE
    click_button "Import people"
    assert_text "Contacts: 1 companies have a contact"

    visit new_import_path
    attach_file "Apollo accounts CSV", PEOPLE
    click_button "Import accounts"
    assert_text "doesn't look like an Apollo accounts export"
    assert_text "Columns found: First Name, Last Name"
  end

  test "the upload page fits a phone screen" do
    visit new_import_path
    page.driver.browser.manage.window.resize_to(390, 900)
    assert_operator page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), :<=, 0
    assert_selector "label", text: /apollo accounts csv/i
  end
end
