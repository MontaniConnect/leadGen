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

  # The Why column of the companies table (the last table on the page; the first lists fail reasons).
  def why_cells = css_select("table").last.css("tbody tr").map { |row| row.css("td")[5].text.squish }

  test "the list has a website column with a safe link" do
    Company.find_by!(name: "Good Co").update!(website: "https://www.goodco.com", domain: "goodco.com")
    get dashboard_path
    assert_select "th", text: "Website"
    assert_select "a[href='https://www.goodco.com'][target=_blank][rel='noopener noreferrer']", text: "goodco.com"
  end

  test "a company with no website shows an empty cell, not a broken link" do
    get dashboard_path
    assert_select "a[href='']", count: 0
    assert_select "a[href='https://']", count: 0
  end

  test "the Why header toggles the sort: A to Z, then Z to A, then A to Z again" do
    Company.create!(name: "Zed", employees: 50, country: "United States", technologies: "Salesforce", keywords: "")
    Company.create!(name: "Amy", employees: 50, country: "United States", technologies: "AWS", keywords: "")
    Prefilter::Runner.new.call

    get dashboard_path(sort: "why", dir: "asc")
    asc = why_cells.reject(&:empty?)
    assert_operator asc.size, :>=, 3
    assert_equal asc.sort, asc
    assert_select "th[aria-sort=ascending] a", text: "Why ↑"
    assert_select "th a[href*='dir=desc']"

    get dashboard_path(sort: "why", dir: "desc")
    desc = why_cells.reject(&:empty?)
    assert_equal desc.sort.reverse, desc
    assert_select "th[aria-sort=descending] a", text: "Why ↓"
    assert_select "th a[href*='dir=asc']"
  end

  test "without a sort the header is unsorted and the default order is unchanged" do
    get dashboard_path
    assert_select "th[aria-sort=none] a", text: "Why"
    assert_select "th a[href*='dir=asc']"
  end

  test "sorting keeps the current filters, and an unknown direction falls back to A to Z" do
    get dashboard_path(status: "fail", sort: "why", dir: "sideways")
    assert_select "th[aria-sort=ascending]"
    assert_select "th a[href*='status=fail']"
  end
end
