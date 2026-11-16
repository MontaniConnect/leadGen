require "test_helper"

class Contacts::RunnerTest < ActiveSupport::TestCase
  setup do
    @with = Company.create!(name: "With", prefilter_status: "pass")
    @with.contacts.create!(first_name: "Ada", title: "CEO")
    @without = Company.create!(name: "Without", prefilter_status: "pass")
    @failed = Company.create!(name: "Failed", prefilter_status: "fail")
    @failed.contacts.create!(first_name: "Zed", title: "CEO")
  end

  test "selects contacts, flags not found, and ignores failed companies" do
    tally = Contacts::Runner.new.call

    assert_equal({ "selected" => 1, "not_found" => 1 }, tally)
    assert_equal "Ada", @with.reload.selected_contact.first_name
    assert_equal "not_found", @without.reload.contact_status
    assert_equal "pending", @failed.reload.contact_status
    assert_equal [ @without ], Company.needing_site_contact.to_a
  end

  test "re-running picks up a newly added contact and leaves the queue" do
    Contacts::Runner.new.call
    @without.contacts.create!(first_name: "Site", title: "Founder", source: "site")
    Contacts::Runner.new.call

    assert_equal "selected", @without.reload.contact_status
    assert_equal "site", @without.selected_contact.source
    assert_empty Company.needing_site_contact
  end
end
