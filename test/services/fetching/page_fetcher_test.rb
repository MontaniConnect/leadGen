require "test_helper"

class Fetching::PageFetcherTest < ActiveSupport::TestCase
  include FetchingTestHelper

  def fetch(path = "/about", &stubs)
    http = stubbed_http do |s|
      s.get("https://acme.com/robots.txt") { [ 200, TEXT, "User-agent: *\nDisallow: /private" ] }
      stubs.call(s)
    end
    page_fetcher_for(http).call("https://acme.com#{path}")
  end

  test "ok returns html" do
    result = fetch { |s| s.get("/about") { [ 200, HTML, "<p>hi</p>" ] } }
    assert_equal "ok", result.status
    assert_equal "<p>hi</p>", result.html
  end

  test "404 is not_found, 403 is blocked, 500 is error" do
    assert_equal "not_found", fetch { |s| s.get("/about") { [ 404, HTML, "" ] } }.status
    assert_equal "blocked", fetch { |s| s.get("/about") { [ 403, HTML, "" ] } }.status
    assert_equal "error", fetch { |s| s.get("/about") { [ 500, HTML, "" ] } }.status
  end

  test "timeout and connection failure are recorded without raising" do
    assert_equal "timeout", fetch { |s| s.get("/about") { raise Faraday::TimeoutError } }.status
    assert_equal "error", fetch { |s| s.get("/about") { raise Faraday::ConnectionFailed, "boom" } }.status
  end

  test "robots.txt disallow is blocked without requesting the page" do
    result = fetch("/private/x") { |_| } # no page stub: a request would raise
    assert_equal "blocked", result.status
  end

  test "non-html content is an error, not stored text" do
    result = fetch { |s| s.get("/about") { [ 200, TEXT, "plain" ] } }
    assert_equal "error", result.status
    assert_equal "", result.html
  end

  test "retries a 503 then succeeds" do
    attempts = 0
    http = stubbed_http(max_retries: 1) do |s|
      s.get("https://acme.com/robots.txt") { NO_ROBOTS }
      s.get("/about") { attempts += 1; attempts == 1 ? [ 503, HTML, "" ] : [ 200, HTML, "<p>ok</p>" ] }
    end
    assert_equal "ok", page_fetcher_for(http).call("https://acme.com/about").status
    assert_equal 2, attempts
  end
end
