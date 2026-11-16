module Fetching
  # Enforces a minimum gap between requests to the same host.
  class RateLimiter
    def initialize(delay:, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, sleeper: ->(s) { sleep(s) })
      @delay = delay
      @clock = clock
      @sleeper = sleeper
      @last_request = {}
    end

    def wait(host)
      last = @last_request[host]
      if last
        remaining = @delay - (@clock.call - last)
        @sleeper.call(remaining) if remaining.positive?
      end
      @last_request[host] = @clock.call
    end
  end
end
