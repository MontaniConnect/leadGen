require "application_system_test_case"

class ContactFlowTest < ApplicationSystemTestCase
  include LeadsTestHelper

  test "a lead with no contact: add one yourself and the contact card and LinkedIn button update" do
    lead = lead(name: "Acme")
    lead.update!(selected_contact: nil, contact_status: "not_found")
    lead.contacts.destroy_all
    visit lead_path(lead)

    assert_text "No contact found"
    find("summary", text: "Add a contact yourself").click
    fill_in "First name", with: "Pat"
    fill_in "Last name", with: "Nguyen"
    fill_in "Title", with: "Founder & CEO"
    fill_in "LinkedIn profile link (optional)", with: "https://www.linkedin.com/in/pat"
    click_button "Save contact"

    assert_text "Contact saved: Pat Nguyen."
    assert_selector ".contact-name", text: "Pat Nguyen"
    assert_link "Open LinkedIn profile", href: "https://www.linkedin.com/in/pat"
    assert_no_text "Add a contact yourself"
  end

  test "the prefilter page button starts the website lookups and tells you what happens next" do
    Company.create!(name: "Alpha", domain: "alpha.com", prefilter_status: "pass", contact_status: "not_found")
    visit dashboard_path
    click_button "Look for contacts on their websites (1)"

    assert_text "Looking for contacts on 1 company website"
    assert_current_path dashboard_path
  end
end
