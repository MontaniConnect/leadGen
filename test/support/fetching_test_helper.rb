# Builds a Fetching stack on top of Faraday's stub adapter, with no sleeping and no network.
module FetchingTestHelper
  HTML = { "content-type" => "text/html; charset=utf-8" }.freeze
  TEXT = { "content-type" => "text/plain" }.freeze
  NO_ROBOTS = [ 404, TEXT, "" ].freeze

  def words(count, word = "lorem") = ([ word ] * count).join(" ")

  def page_html(body, nav: "")
    "<html><body><nav>#{nav}</nav><main>#{body}</main></body></html>"
  end

  def stubbed_http(max_retries: 0, &block)
    stubs = Faraday::Adapter::Test::Stubs.new(&block)
    Fetching::HttpClient.new(user_agent: "MontaniLeadResearchBot/1.0", max_retries: max_retries, adapter: [ :test, stubs ])
  end

  def page_fetcher_for(http)
    limiter = Fetching::RateLimiter.new(delay: 0, sleeper: ->(_) { })
    robots = Fetching::RobotsPolicy.new(http: http, limiter: limiter, user_agent: "MontaniLeadResearchBot/1.0")
    Fetching::PageFetcher.new(http: http, limiter: limiter, robots: robots)
  end
end
