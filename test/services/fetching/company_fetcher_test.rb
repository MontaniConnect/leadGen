require "test_helper"

class Fetching::CompanyFetcherTest < ActiveSupport::TestCase
  include FetchingTestHelper

  setup do
    @company = Company.create!(name: "Acme", domain: "acme.com", prefilter_status: "pass")
    @home = page_html("<h1>Acme</h1><p>#{words(60)}</p>",
                      nav: '<a href="/about">About</a><a href="/careers">Careers</a><a href="/blog">Blog</a>')
  end

  def fetcher_with(&stubs)
    http = stubbed_http do |s|
      s.get("https://acme.com/robots.txt") { NO_ROBOTS }
      stubs.call(s)
    end
    Fetching::CompanyFetcher.new(page_fetcher_factory: -> { page_fetcher_for(http) })
  end

  test "stores clean text for home, about, careers and blog" do
    fetcher = fetcher_with do |s|
      s.get("https://acme.com/") { [ 200, HTML, @home ] }
      %w[about careers blog].each { |path| s.get("/#{path}") { [ 200, HTML, page_html("<p>#{words(50, path)}</p>") ] } }
    end
    outcome = fetcher.call(@company)

    assert_equal 4, outcome.pages_fetched
    pages = @company.pages.index_by(&:kind)
    assert_equal %w[about blog careers home], pages.keys.sort
    assert pages.values.all? { |p| p.status == "ok" && p.fetched_at }
    assert_not_includes pages["home"].text, "About" # navigation stripped
    assert_equal 60 + 1, pages["home"].word_count
    assert_equal "https://acme.com/careers", pages["home"].discovered_urls["careers"]
  end

  test "records failures per page and does not crash" do
    fetcher = fetcher_with do |s|
      s.get("https://acme.com/") { [ 200, HTML, @home ] }
      s.get("/about") { [ 404, HTML, "" ] }
      s.get("/careers") { raise Faraday::TimeoutError }
      s.get("/blog") { [ 403, HTML, "" ] }
    end
    fetcher.call(@company)

    statuses = @company.pages.pluck(:kind, :status).to_h
    assert_equal({ "home" => "ok", "about" => "not_found", "careers" => "timeout", "blog" => "blocked" }, statuses)
    assert_nil @company.pages.find_by!(kind: "about").text
  end

  test "pages with too little text are stored as empty" do
    fetcher = fetcher_with { |s| s.get("https://acme.com/") { [ 200, HTML, page_html("<p>Coming soon</p>") ] } }
    fetcher.call(@company)
    assert_equal "empty", @company.pages.find_by!(kind: "home").status
  end

  test "pages fetched within the window are skipped, failed ones are retried" do
    fetcher_with do |s|
      s.get("https://acme.com/") { [ 200, HTML, @home ] }
      s.get("/about") { [ 200, HTML, page_html("<p>#{words(50)}</p>") ] }
      s.get("/careers") { raise Faraday::TimeoutError }
      s.get("/blog") { [ 404, HTML, "" ] }
    end.call(@company)

    requests = []
    second = fetcher_with do |s|
      s.get("/careers") { requests << "careers"; [ 200, HTML, page_html("<p>#{words(50)}</p>") ] }
    end.call(@company)

    assert_equal 3, second.pages_skipped
    assert_equal 1, second.pages_fetched
    assert_equal [ "careers" ], requests
    assert_equal "ok", @company.pages.find_by!(kind: "careers").status
  end

  test "pages older than the refetch window are fetched again" do
    fetcher_with { |s| s.get("https://acme.com/") { [ 200, HTML, page_html("<p>#{words(50)}</p>") ] } }.call(@company)
    @company.pages.update_all(fetched_at: 31.days.ago)

    outcome = fetcher_with { |s| s.get("https://acme.com/") { [ 200, HTML, page_html("<p>#{words(50)}</p>") ] } }.call(@company)
    assert_equal 1, outcome.pages_fetched
  end

  test "reads a leader off the about page when the company has no contact" do
    about = page_html("<p>#{words(50)}</p><h3>Jane Doe</h3><p>Founder &amp; CEO</p>")
    outcome = fetcher_with do |s|
      s.get("https://acme.com/") { [ 200, HTML, @home ] }
      s.get("/about") { [ 200, HTML, about ] }
      s.get("/careers") { [ 404, HTML, "" ] }
      s.get("/blog") { [ 404, HTML, "" ] }
    end.call(@company)

    assert_equal "Jane", outcome.site_contact.first_name
    assert_equal "site", @company.contacts.first.source
  end

  test "does not add a site contact when one is already selected" do
    @company.update!(contact_status: "selected")
    outcome = fetcher_with do |s|
      s.get("https://acme.com/") { [ 200, HTML, @home ] }
      s.get("/about") { [ 200, HTML, page_html("<p>#{words(50)}</p><p>Jane Doe, CEO</p>") ] }
      s.get("/careers") { [ 404, HTML, "" ] }
      s.get("/blog") { [ 404, HTML, "" ] }
    end.call(@company)

    assert_nil outcome.site_contact
    assert_equal 0, @company.contacts.count
  end

  test "company without a domain is skipped" do
    outcome = Fetching::CompanyFetcher.new(page_fetcher_factory: -> { flunk }).call(Company.create!(name: "No Site"))
    assert_equal 0, outcome.pages_fetched
  end

  test "robots.txt that blocks everything stores blocked pages" do
    http = stubbed_http { |s| s.get("https://acme.com/robots.txt") { [ 200, TEXT, "User-agent: *\nDisallow: /" ] } }
    Fetching::CompanyFetcher.new(page_fetcher_factory: -> { page_fetcher_for(http) }).call(@company)
    assert_equal [ "blocked" ], @company.pages.pluck(:status)
  end
end
