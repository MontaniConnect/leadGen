module Scoring
  # Scores one company with a direct API call. Skips companies that already have an ok evaluation
  # unless forced. API errors are recorded as failed evaluations so a single company can be retried alone.
  # The budget guard runs before the call and raises Budget::Guard::CapReached when it would not fit.
  class CompanyScorer
    def initialize(gateway:, request_builder: RequestBuilder.new, recorder: Recorder.new, guard: Budget::Guard.new)
      @gateway = gateway
      @request_builder = request_builder
      @recorder = recorder
      @guard = guard
    end

    # Returns the Evaluation, or nil when skipped.
    def call(company, force: false, run: nil)
      return nil if !force && company.evaluations.ok.exists?

      request = @request_builder.call(company)
      @guard.authorize!(request)
      @recorder.call(company, @gateway.message(request), run: run)
    rescue Anthropic::Errors::APIError => e
      @recorder.record_failure(company, "api error: #{e.class.name.demodulize}: #{e.message.to_s.truncate(200)}", run: run)
    end
  end
end
