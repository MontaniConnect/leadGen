require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  include LeadsTestHelper

  setup do
    @lead = lead(name: "Acme")
    @lead.update!(selected_contact: nil, contact_status: "not_found")
    @lead.contacts.destroy_all
  end

  def add(**contact) = post(lead_contact_path(@lead, tier: "Hot"), params: { contact: contact })

  test "the lead screen offers a form only when there is no contact, with labelled fields" do
    get lead_path(@lead)
    assert_select "details summary", text: "Add a contact yourself"
    %w[first_name last_name title linkedin_url].each { |field| assert_select "label[for=contact_#{field}]" }
    assert_select "input[type=submit][value='Save contact']"

    add(first_name: "Pat", title: "CEO")
    get lead_path(@lead)
    assert_select "details summary", text: "Add a contact yourself", count: 0
  end

  test "a saved contact becomes the lead's contact, marked manual, with its LinkedIn link on the screen" do
    add(first_name: " Pat ", last_name: "Nguyen", title: "Founder & CEO", linkedin_url: "https://www.linkedin.com/in/pat")

    assert_redirected_to lead_path(@lead, tier: "Hot")
    contact = @lead.reload.selected_contact
    assert_equal [ "Pat", "Nguyen", "Founder & CEO", "manual" ], contact.values_at(:first_name, :last_name, :title, :source)
    assert_equal "selected", @lead.contact_status
    assert_match(/Contact saved: Pat Nguyen\./, flash[:notice])

    follow_redirect!
    assert_select ".contact-name", text: "Pat Nguyen"
    assert_select "a.btn[href='https://www.linkedin.com/in/pat']", text: "Open LinkedIn profile"
  end

  test "a name is required" do
    add(first_name: "", last_name: " ", title: "CEO")
    assert_equal "Enter at least a first or last name.", flash[:alert]
    assert_equal 0, @lead.contacts.count
    assert_nil @lead.reload.selected_contact
  end

  test "a LinkedIn link that is not a web address is refused, an empty one is fine" do
    add(first_name: "Pat", linkedin_url: "javascript:alert(1)")
    assert_match(/must start with https/, flash[:alert])
    assert_equal 0, @lead.contacts.count

    add(first_name: "Pat", linkedin_url: "")
    assert_equal 1, @lead.contacts.count
    assert_nil Contact.where(company: @lead).last.linkedin_url
  end

  test "the added contact is used for messages and stays when a better-titled contact is imported later" do
    add(first_name: "Pat", title: "Operations Coordinator")
    @lead.contacts.create!(first_name: "Big", last_name: "Boss", title: "CEO", source: "apollo")
    Contacts::Runner.new(scope: Company.where(id: @lead.id)).call

    assert_equal "Pat", @lead.reload.selected_contact.first_name
    assert_equal "Pat", Drafting::EvidenceFormatter.new.call(@lead).slice(/Contact first name: \w+/).split.last
  end
end
