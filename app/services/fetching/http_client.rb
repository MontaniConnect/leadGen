require "faraday"
require "faraday/retry"
require "faraday/follow_redirects"

module Fetching
  # Thin Faraday wrapper. #get never raises: failures come back as Response#error (:timeout or :network).
  # Pass `adapter: [:test, stubs]` in tests.
  class HttpClient
    MAX_BODY_BYTES = 1_500_000

    def initialize(user_agent:, open_timeout: 5, read_timeout: 10, max_retries: 2, max_redirects: 3, adapter: nil)
      @connection = Faraday.new(headers: { "User-Agent" => user_agent, "Accept" => "text/html,text/plain" }) do |f|
        f.options.open_timeout = open_timeout
        f.options.timeout = read_timeout
        f.response :follow_redirects, limit: max_redirects
        f.request :retry, max: max_retries, interval: 0.5, backoff_factor: 2,
                          exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::RetriableResponse ],
                          retry_statuses: [ 429, 502, 503, 504 ]
        f.adapter(*(adapter || Faraday.default_adapter))
      end
    end

    def self.from_settings(**overrides)
      new(
        user_agent: Setting.get("fetching.user_agent"), open_timeout: Setting.get("fetching.open_timeout"),
        read_timeout: Setting.get("fetching.read_timeout"), max_retries: Setting.get("fetching.max_retries"),
        max_redirects: Setting.get("fetching.max_redirects"), **overrides
      )
    end

    def get(url)
      reply = @connection.get(url)
      Response.new(status: reply.status, body: reply.body.to_s.byteslice(0, MAX_BODY_BYTES).to_s.scrub,
                   url: reply.env.url.to_s, content_type: reply.headers["content-type"].to_s, error: nil)
    rescue Faraday::TimeoutError
      failure(url, :timeout)
    rescue Faraday::Error, URI::InvalidURIError
      failure(url, :network)
    end

    private

    def failure(url, error)
      Response.new(status: nil, body: "", url: url, content_type: "", error: error)
    end
  end
end
