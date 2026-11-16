require "test_helper"

class Leads::LinkedinTargetTest < ActiveSupport::TestCase
  def company(person: nil, page: nil)
    company = Company.create!(name: "Acme", linkedin_url: page)
    contact = company.contacts.create!(first_name: "Ada", title: "CEO", linkedin_url: person)
    company.update!(selected_contact: contact)
    company
  end

  test "1. the contact's profile wins when present" do
    target = Leads::LinkedinTarget.call(company(person: "https://linkedin.com/in/ada", page: "https://linkedin.com/company/acme"))
    assert_equal [ :profile, "https://linkedin.com/in/ada", "Open LinkedIn profile" ], target.to_h.values
  end

  test "2. otherwise the company page, labelled as such" do
    target = Leads::LinkedinTarget.call(company(page: "https://linkedin.com/company/acme"))
    assert_equal [ :company_page, "https://linkedin.com/company/acme", "Company page (no contact found)" ], target.to_h.values
  end

  test "3. otherwise plain text and no URL" do
    target = Leads::LinkedinTarget.call(company)
    assert_equal [ :none, nil, "No LinkedIn link" ], target.to_h.values
  end

  test "a lead with no contact at all still falls back to the company page" do
    bare = Company.create!(name: "Bare", linkedin_url: "https://linkedin.com/company/bare")
    assert_equal :company_page, Leads::LinkedinTarget.call(bare).kind
  end

  test "non-web URLs are never linked" do
    bad = company(person: "javascript:alert(1)", page: "data:text/html,x")
    assert_equal :none, Leads::LinkedinTarget.call(bad).kind
  end
end
