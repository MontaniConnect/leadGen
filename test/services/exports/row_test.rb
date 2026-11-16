require "test_helper"

class Exports::RowTest < ActiveSupport::TestCase
  include LeadsTestHelper

  def values_for(company) = Exports::Row.new.values(Company.preload(:evaluations, :selected_contact, :messages).find(company.id))
  def cell(values, header) = values[Exports::Row::HEADERS.index(header)]

  test "columns are in the agreed order, with the Apollo Account Id key last" do
    assert_equal [ "Company", "URL", "Contact", "Title", "Contact LinkedIn URL", "Staffing score", "Automation score",
                   "Confidence", "Tier", "Why now", "Lead with", "Message variant 1", "Message variant 2",
                   "Message variant 3", "Key source URL", "Reply Result", "Apollo Account Id" ], Exports::Row::HEADERS
  end

  test "a drafted lead fills every column" do
    company = lead(name: "Acme", staffing: 8, automation: 6, apollo_account_id: "a-1", reply_result: "interested")
    values = values_for(company)

    assert_equal "Acme", cell(values, "Company")
    assert_equal "https://www.acme.com", cell(values, "URL")
    assert_equal "Ada Lovelace", cell(values, "Contact")
    assert_equal "CEO", cell(values, "Title")
    assert_equal "https://www.linkedin.com/in/ada", cell(values, "Contact LinkedIn URL")
    assert_equal [ 8, 6 ], [ cell(values, "Staffing score"), cell(values, "Automation score") ]
    assert_equal [ "Medium", "Hot" ], [ cell(values, "Confidence"), cell(values, "Tier") ]
    assert_equal "Raised Series A in October", cell(values, "Why now")
    assert_equal "Salesforce specialists", cell(values, "Lead with")
    assert_equal "https://acme.com/careers", cell(values, "Key source URL")
    assert_equal "Interested", cell(values, "Reply Result")
    assert_equal "a-1", cell(values, "Apollo Account Id")
  end

  test "message variants map to 1 curious, 2 founder, 3 offer, and use the edited text" do
    company = lead(name: "Acme")
    company.messages.find_by!(label: "curious_question").update!(body: "Hi Ada, my edited opener?", status: "edited")
    values = values_for(company)

    assert_equal "Hi Ada, my edited opener?", cell(values, "Message variant 1")
    assert_equal DraftingTestHelper::FOUNDER, cell(values, "Message variant 2")
    assert_equal DraftingTestHelper::OFFER, cell(values, "Message variant 3")
  end

  test "a lead with no founder variant leaves that cell blank, not shifted" do
    company = lead(name: "Acme")
    company.messages.find_by!(label: "founder_time").destroy
    values = values_for(company)

    assert_equal "", cell(values, "Message variant 2")
    assert_equal DraftingTestHelper::OFFER, cell(values, "Message variant 3")
  end

  test "contact LinkedIn falls back to the company page, then blank" do
    company = lead(name: "Acme", linkedin_url: "https://linkedin.com/company/acme")
    company.selected_contact.update!(linkedin_url: nil)
    assert_equal "https://linkedin.com/company/acme", cell(values_for(company), "Contact LinkedIn URL")

    company.update!(linkedin_url: nil)
    assert_equal "", cell(values_for(company), "Contact LinkedIn URL")
  end

  test "key source URL skips Apollo sources and falls back to why-now, then blank" do
    company = lead(name: "Acme")
    evaluation = company.current_evaluation
    evaluation.update!(signals: [ { "signal" => "x", "source" => "Apollo: Keywords" } ],
                       why_now_source: "https://acme.com/news")
    assert_equal "https://acme.com/news", cell(values_for(company), "Key source URL")

    evaluation.update!(why_now_source: "Apollo: Last Raised At")
    assert_equal "", cell(values_for(company), "Key source URL")
  end

  test "a lead without a contact or drafts still exports" do
    company = lead(name: "Bare", drafted: false)
    company.update!(selected_contact: nil)
    values = values_for(company)

    assert_equal "", cell(values, "Contact")
    assert_equal [ "", "", "" ], [ cell(values, "Message variant 1"), cell(values, "Message variant 2"), cell(values, "Message variant 3") ]
    assert_equal Exports::Row::HEADERS.size, values.size
  end
end
