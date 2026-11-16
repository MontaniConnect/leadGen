require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    Company.create!(name: "Good Co", employees: 50, country: "United States")
    Company.create!(name: "Tiny Co", employees: 2, country: "United States")
    Prefilter::Runner.new.call
  end

  test "shows counts per reason" do
    get dashboard_path
    assert_response :success
    assert_select "td", text: "employees_below_min"
    assert_select "a", text: "Pass: 1"
  end

  test "filters by reason" do
    get dashboard_path(status: "fail", reason: "employees_below_min")
    assert_select "td", text: "Tiny Co"
    assert_select "td", text: "Good Co", count: 0
  end

  test "shows selected contact and not-found count for passed companies" do
    Company.find_by!(name: "Good Co").contacts.create!(first_name: "Ada", last_name: "L", title: "CEO")
    Contacts::Runner.new.call
    get dashboard_path(status: "pass")

    assert_select "td", text: "Ada L, CEO"
    assert_match "Selected: 1", response.body
  end
end
