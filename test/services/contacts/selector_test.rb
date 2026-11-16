require "test_helper"

class Contacts::SelectorTest < ActiveSupport::TestCase
  setup { @company = Company.create!(name: "Acme") }

  def add(first, title, **attrs)
    @company.contacts.create!({ first_name: first, title: title }.merge(attrs))
  end

  def pick = Contacts::Selector.new.call(@company.reload)

  test "CEO or founder beats CTO beats head of ops beats others" do
    add("Other", "Account Executive")
    add("Ops", "Head of Operations")
    assert_equal "Ops", pick.first_name
    add("Tech", "CTO")
    assert_equal "Tech", pick.first_name
    add("Boss", "Founder & CEO")
    assert_equal "Boss", pick.first_name
  end

  test "senior titles beat unrelated ones" do
    add("Rep", "Sales Rep")
    add("Dir", "Director of Marketing")
    assert_equal "Dir", pick.first_name
  end

  test "assistants and former roles are never selected" do
    add("Asst", "Executive Assistant to the CEO")
    add("Old", "Former CEO")
    assert_nil pick
    add("Rep", "Sales Rep")
    assert_equal "Rep", pick.first_name
  end

  test "ties prefer a contact with a LinkedIn URL, then the earliest" do
    add("NoUrl", "CEO")
    add("Url", "CEO", linkedin_url: "https://linkedin.com/in/url")
    assert_equal "Url", pick.first_name
  end

  test "vice president does not match the president-only wording of a CEO tier" do
    add("VP", "Vice President of Sales")
    add("Cto", "Chief Technology Officer")
    assert_equal "Cto", pick.first_name
  end

  test "no contacts returns nil" do
    assert_nil pick
  end
end
