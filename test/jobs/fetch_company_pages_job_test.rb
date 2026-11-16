require "test_helper"

class FetchCompanyPagesJobTest < ActiveJob::TestCase
  test "fetches the company then re-runs contact selection" do
    company = Company.create!(name: "Acme", domain: "acme.com", prefilter_status: "pass")
    fake = Object.new
    fake.define_singleton_method(:call) { |c| c.contacts.create!(first_name: "Jane", title: "CEO", source: "site") }

    FetchCompanyPagesJob.perform_now(company.id, fetcher: fake)

    assert_equal "selected", company.reload.contact_status
    assert_equal "site", company.selected_contact.source
  end

  test "a deleted company is discarded quietly" do
    assert_nothing_raised { FetchCompanyPagesJob.perform_now(0) }
  end
end
