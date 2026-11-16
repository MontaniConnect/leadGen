require "test_helper"

class Fetching::RateLimiterTest < ActiveSupport::TestCase
  test "sleeps only for the remaining gap on the same host" do
    now = 100.0
    slept = []
    limiter = Fetching::RateLimiter.new(delay: 2, clock: -> { now }, sleeper: ->(s) { slept << s })

    limiter.wait("a.com")           # first request: no wait
    now = 100.5
    limiter.wait("a.com")           # 0.5s elapsed, wait 1.5s
    limiter.wait("b.com")           # other host: no wait
    now = 110
    limiter.wait("a.com")           # long ago: no wait

    assert_equal [ 1.5 ], slept
  end
end
