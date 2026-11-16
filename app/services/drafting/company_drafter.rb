module Drafting
  # Drafts the message variants for one lead in a drafted tier (Hot or Warm by default). Skips other companies or already have an
  # ok draft run unless forced. Retries a full re-draft when a required variant fails validation;
  # every attempt is logged as its own DraftRun so token spend stays visible.
  class CompanyDrafter
    def initialize(gateway:, request_builder: RequestBuilder.new, recorder: Recorder.new,
                   max_attempts: Setting.get("drafting.max_attempts"),
                   fallbacks: Setting.get("drafting.server_side_fallback"), guard: Budget::Guard.new)
      @gateway = gateway
      @guard = guard
      @request_builder = request_builder
      @recorder = recorder
      @max_attempts = max_attempts
      @fallbacks = fallbacks
    end

    # Returns the final DraftRun, or nil when skipped. Raises Budget::Guard::CapReached when the next call won't fit.
    def call(company, force: false, run: nil)
      return nil unless Setting.get("drafting.tiers").include?(company.current_evaluation&.tier)
      return nil if !force && company.draft_runs.where(status: "ok").exists?

      result = nil
      @max_attempts.times do
        result = attempt(company, run)
        break if result.status == "ok"
      end
      result
    end

    private

    def attempt(company, run)
      version = nil
      request = @request_builder.call(company)
      version = @request_builder.prompt_version
      @guard.authorize!(request)
      @recorder.call(company, @gateway.message(request, fallbacks: @fallbacks), run: run, prompt_version: version)
    rescue Anthropic::Errors::APIError => e
      @recorder.record_failure(company, "api error: #{e.class.name.demodulize}: #{e.message.to_s.truncate(200)}",
                               run: run, prompt_version: version || Prompt::VERSION)
    end
  end
end
