module Scoring
  # Parses a reply and stores it as an Evaluation: ok with tier and confidence, or failed with the reason.
  # Tokens and dollar cost are stored either way, so spend is visible even for failures.
  class Recorder
    def initialize(parser: ResponseParser.new, confidence: Confidence.new, tier_rule: TierRule.new,
                   pricing: Budget::Pricing.new)
      @parser = parser
      @confidence = confidence
      @tier_rule = tier_rule
      @pricing = pricing
    end

    def call(company, reply, run: nil, batch: false)
      data = @parser.call(reply)
      store_success(company, data, reply, run, batch)
    rescue ResponseParser::ParseError => e
      record_failure(company, e.message, reply, run: run, batch: batch)
    end

    def record_failure(company, message, reply = nil, run: nil, batch: false)
      company.evaluations.create!(
        { status: "failed", error: message, model: model, prompt_version: Prompt::VERSION, pipeline_run: run }
          .merge(usage_attributes(reply, batch))
      )
    end

    private

    def model = Setting.get("models.scoring")

    def store_success(company, data, reply, run, batch)
      confidence = @confidence.call(company)
      disqualified = data["disqualified"]
      tier = @tier_rule.call(staffing: data["staffing_score"], automation: data["automation_score"],
                             confidence: confidence.level, disqualified: disqualified)
      company.evaluations.create!(
        {
          status: "ok", staffing_score: data["staffing_score"], automation_score: data["automation_score"],
          confidence: confidence.level, useful_sources: confidence.useful_sources, tier: tier,
          signals: data["top_signals"], red_flags: data["red_flags"], offshore_signal: data["offshore_signal"],
          why_now: data["why_now"], why_now_source: data["why_now_source"], lead_with: data["lead_with"],
          disqualified: disqualified, model: model, prompt_version: Prompt::VERSION, raw: data, pipeline_run: run
        }.merge(usage_attributes(reply, batch))
      )
    end

    def usage_attributes(reply, batch)
      return {} unless reply

      { tokens_in: reply.input_tokens, tokens_out: reply.output_tokens, cache_read_tokens: reply.cache_read_tokens,
        cache_write_tokens: reply.cache_write_tokens, cost_usd: cost(reply, batch) }
    end

    # An unpriced model must never lose a paid result: record it at $0 and report loudly.
    def cost(reply, batch)
      @pricing.cost(model: model, input: reply.input_tokens, output: reply.output_tokens, cache_read: reply.cache_read_tokens,
                    cache_write: reply.cache_write_tokens, cache_ttl: Setting.get("scoring.cache_ttl"), batch: batch)
    rescue Budget::Pricing::UnknownModel => e
      Rails.error.report(e, handled: true)
      0
    end
  end
end
