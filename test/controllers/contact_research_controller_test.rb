require "test_helper"

class ContactResearchControllerTest < ActionDispatch::IntegrationTest
  def make(name, **attrs)
    Company.create!({ name: name, domain: "#{name.downcase.delete(' ')}.com", prefilter_status: "pass", contact_status: "not_found" }.merge(attrs))
  end

  test "the button queues a lookup for each passed company without a contact and says how many" do
    a = make("Alpha")
    b = make("Bravo")
    assert_enqueued_jobs 2, only: FindContactJob do
      post contact_research_path
    end
    assert_redirected_to dashboard_path
    assert_match(/Looking for contacts on 2 company websites/, flash[:notice])
    assert_enqueued_with(job: FindContactJob, args: [ a.id ])
    assert_enqueued_with(job: FindContactJob, args: [ b.id ])
  end

  test "companies that already have a contact, failed the prefilter or have no website are left out" do
    make("Wanted")
    make("HasContact", contact_status: "selected")
    make("Failed", prefilter_status: "fail")
    make("NoSite", domain: nil)
    assert_enqueued_jobs 1, only: FindContactJob do
      post contact_research_path
    end
    assert_match(/1 company website\./, flash[:notice])
  end

  test "a recent check is not repeated, an old one is" do
    make("Recent", contact_researched_at: 5.days.ago, contact_research_result: "no_clear_name")
    old = make("Old", contact_researched_at: 31.days.ago, contact_research_result: "no_clear_name")
    assert_enqueued_jobs 1, only: FindContactJob do
      post contact_research_path
    end
    assert_enqueued_with(job: FindContactJob, args: [ old.id ])
  end

  test "with nothing to look up it says so and queues nothing" do
    assert_no_enqueued_jobs only: FindContactJob do
      post contact_research_path
    end
    assert_match(/Nothing to look up/, flash[:notice])
  end

  test "the prefilter page shows the button with its count, and what was checked without luck" do
    make("Alpha")
    make("Checked", contact_researched_at: 2.days.ago, contact_research_result: "no_clear_name")
    get dashboard_path

    assert_select "button", text: "Look for contacts on their websites (1)"
    assert_select ".hint", text: /1 company websites were checked and showed no clearly named leader/
    assert_select ".hint", text: /never uses LinkedIn/
  end

  test "the button is disabled when there is nothing to look up" do
    get dashboard_path
    assert_select "button[disabled]", text: "Look for contacts on their websites (0)"
  end
end
