require "test_helper"

class Fetching::RobotsPolicyTest < ActiveSupport::TestCase
  include FetchingTestHelper

  def policy(status: 200, body: "")
    http = stubbed_http { |s| s.get("https://acme.com/robots.txt") { [ status, TEXT, body ] } }
    limiter = Fetching::RateLimiter.new(delay: 0, sleeper: ->(_) { })
    Fetching::RobotsPolicy.new(http: http, limiter: limiter, user_agent: "MontaniLeadResearchBot/1.0 (+https://montani.ph)")
  end

  test "disallow rules apply to the wildcard group" do
    robots = policy(body: "User-agent: *\nDisallow: /private\nAllow: /private/open")
    assert robots.allowed?("https://acme.com/about")
    assert_not robots.allowed?("https://acme.com/private/x")
    assert robots.allowed?("https://acme.com/private/open/page")
  end

  test "a group naming our bot overrides the wildcard group" do
    robots = policy(body: "User-agent: *\nDisallow: /\n\nUser-agent: MontaniLeadResearchBot\nDisallow: /secret")
    assert robots.allowed?("https://acme.com/about")
    assert_not robots.allowed?("https://acme.com/secret")
  end

  test "disallow everything blocks, empty disallow allows" do
    assert_not policy(body: "User-agent: *\nDisallow: /").allowed?("https://acme.com/about")
    assert policy(body: "User-agent: *\nDisallow:").allowed?("https://acme.com/about")
  end

  test "wildcards and end anchors" do
    robots = policy(body: "User-agent: *\nDisallow: /*.pdf$\nDisallow: /tmp*")
    assert_not robots.allowed?("https://acme.com/files/a.pdf")
    assert robots.allowed?("https://acme.com/files/a.pdf.html")
    assert_not robots.allowed?("https://acme.com/tmpfiles")
  end

  test "missing robots.txt allows, unreadable robots.txt denies" do
    assert policy(status: 404).allowed?("https://acme.com/about")
    assert_not policy(status: 503).allowed?("https://acme.com/about")
  end

  test "robots.txt is fetched once per host" do
    calls = 0
    http = stubbed_http { |s| s.get("https://acme.com/robots.txt") { calls += 1; [ 200, TEXT, "" ] } }
    limiter = Fetching::RateLimiter.new(delay: 0, sleeper: ->(_) { })
    robots = Fetching::RobotsPolicy.new(http: http, limiter: limiter, user_agent: "Bot/1")
    2.times { robots.allowed?("https://acme.com/a") }
    assert_equal 1, calls
  end
end
