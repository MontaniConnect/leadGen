module Partnering
  # Drafts the partnership message for one staffing-firm candidate. Skips anyone who is not a candidate or
  # already has one, unless forced. Retries once if the message fails the checks. The budget guard runs before every call.
  class Drafter
    def initialize(gateway:, request_builder: RequestBuilder.new, recorder: Recorder.new,
                   max_attempts: Setting.get("drafting.max_attempts"), guard: Budget::Guard.new)
      @gateway = gateway
      @request_builder = request_builder
      @recorder = recorder
      @max_attempts = max_attempts
      @guard = guard
    end

    # Returns the final DraftRun, or nil when skipped.
    def call(company, force: false, run: nil)
      return nil unless Company.partner_candidates.exists?(company.id)
      return nil if !force && company.messages.exists?(label: "partnership")

      result = nil
      @max_attempts.times do
        result = attempt(company, run)
        break if result.status == "ok"
      end
      result
    end

    private

    def attempt(company, run)
      request = @request_builder.call(company)
      @guard.authorize!(request)
      @recorder.call(company, @gateway.message(request), run: run)
    rescue Anthropic::Errors::APIError => e
      @recorder.record_failure(company, "api error: #{e.class.name.demodulize}: #{e.message.to_s.truncate(200)}",
                               run: run, prompt_version: Prompt::VERSION)
    end
  end
end
