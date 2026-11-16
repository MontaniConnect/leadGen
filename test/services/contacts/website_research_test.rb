require "test_helper"

class Contacts::WebsiteResearchTest < ActiveSupport::TestCase
  include FetchingTestHelper

  setup do
    @company = Company.create!(name: "Acme", domain: "acme.com", prefilter_status: "pass")
    @home = page_html("<h1>Acme</h1><p>#{words(60)}</p>",
                      nav: '<a href="/about">About</a><a href="/careers">Careers</a><a href="/blog">Blog</a>')
  end

  def about_with(text) = page_html("<p>#{words(50)}</p>#{text}")

  def research(about_status: 200, about_html: about_with(""), company: @company)
    http = stubbed_http do |s|
      s.get("https://acme.com/robots.txt") { NO_ROBOTS }
      s.get("https://acme.com/") { [ 200, HTML, @home ] }
      s.get("/about") { [ about_status, HTML, about_html ] }
      # careers and blog are NOT stubbed: requesting them would raise, which proves they are not fetched
    end
    fetcher = Fetching::CompanyFetcher.new(page_fetcher_factory: -> { page_fetcher_for(http) })
    Contacts::WebsiteResearch.new(fetcher: fetcher).call(company)
  end

  test "finds a clearly labelled leader on the About page and selects them" do
    outcome = research(about_html: about_with("<h3>Jane Doe</h3><p>Founder &amp; CEO</p>"))

    assert_equal :found, outcome.status
    assert_equal [ "Jane Doe", "Founder & CEO", "site" ], [ outcome.contact.full_name, outcome.contact.title, outcome.contact.source ]
    @company.reload
    assert_equal "selected", @company.contact_status
    assert_equal outcome.contact, @company.selected_contact
    assert_equal "found", @company.contact_research_result
    assert_not_nil @company.contact_researched_at
  end

  test "it re-reads an About page that was already fetched, which is what makes the button useful" do
    http = stubbed_http do |s|
      s.get("https://acme.com/robots.txt") { NO_ROBOTS }
      s.get("https://acme.com/") { [ 200, HTML, @home ] }
      s.get("/about") { [ 200, HTML, about_with("") ] }
      s.get("/careers") { [ 200, HTML, page_html("<p>#{words(50)}</p>") ] }
      s.get("/blog") { [ 200, HTML, page_html("<p>#{words(50)}</p>") ] }
    end
    Fetching::CompanyFetcher.new(page_fetcher_factory: -> { page_fetcher_for(http) }).call(@company)
    assert @company.pages.find_by!(kind: "about").fresh?(days: 30), "the About page is cached as fresh"
    assert_equal 0, @company.contacts.count

    assert_equal :found, research(about_html: about_with("<p>Sam Lee, CTO</p>")).status
    assert_equal "Lee", @company.reload.selected_contact.last_name
  end

  test "only the About page is requested, not careers or the blog" do
    assert_nothing_raised { research(about_html: about_with("<p>Jane Doe, CEO</p>")) }
  end

  test "an About page with no clearly named leader is reported, and remembered" do
    outcome = research(about_html: about_with("<p>We are a friendly team that loves software.</p>"))

    assert_equal [ :no_clear_name, nil ], [ outcome.status, outcome.contact ]
    @company.reload
    assert_equal "not_found", @company.contact_status
    assert_equal "no_clear_name", @company.contact_research_result
  end

  test "an About page that cannot be read is reported as unreachable" do
    assert_equal :site_unreachable, research(about_status: 404).status
    assert_equal "site_unreachable", @company.reload.contact_research_result
  end

  test "a company with no website is not looked up at all" do
    bare = Company.create!(name: "No Site", prefilter_status: "pass")
    outcome = Contacts::WebsiteResearch.new(fetcher: Object.new).call(bare)
    assert_equal :no_website, outcome.status
  end

  test "a company that already has a contact is left alone, with no web request" do
    contact = @company.contacts.create!(first_name: "Ada", title: "CEO", source: "manual")
    @company.update!(selected_contact: contact, contact_status: "selected")
    outcome = Contacts::WebsiteResearch.new(fetcher: Object.new).call(@company)

    assert_equal [ :already_has_contact, contact ], [ outcome.status, outcome.contact ]
    assert_nil @company.reload.contact_researched_at
  end

  test "the background job hands the company to the researcher and ignores a deleted one" do
    seen = []
    researcher = Object.new
    researcher.define_singleton_method(:call) { |company| seen << company.name }
    FindContactJob.perform_now(@company.id, researcher: researcher)
    assert_equal [ "Acme" ], seen
    assert_nothing_raised { FindContactJob.perform_now(0, researcher: researcher) }
  end

  test "a contact added by hand is never replaced by an automatic pick, even a better-titled one" do
    manual = @company.contacts.create!(first_name: "Pat", title: "Operations Coordinator", source: "manual")
    @company.contacts.create!(first_name: "Big", last_name: "Boss", title: "CEO", source: "apollo")

    assert_equal manual, Contacts::Selector.new.call(@company.reload)
    Contacts::Runner.new(scope: Company.where(id: @company.id)).call
    assert_equal manual, @company.reload.selected_contact
  end
end
