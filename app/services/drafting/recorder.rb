module Drafting
  # Turns a reply into a DraftRun plus Message rows, enforcing the variant rules in code:
  #  - curious_question and low_pressure_offer are required and must pass the validator;
  #  - founder_time is kept only when the model cites evidence AND its text passes the validator,
  #    otherwise it is dropped and the company gets two variants.
  class Recorder
    class Rejected < StandardError; end

    REQUIRED = %w[curious_question low_pressure_offer].freeze
    NO_EVIDENCE = "not found".freeze

    def initialize(parser: Scoring::ResponseParser.new(schema: Schema), validator: MessageValidator.new,
                   pricing: Budget::Pricing.new)
      @parser = parser
      @validator = validator
      @pricing = pricing
    end

    def call(company, reply, run: nil, prompt_version: Prompt::VERSION)
      data = @parser.call(reply)
      variants = accepted_variants(data)
      persist(company, reply, data, variants, run, prompt_version)
    rescue Scoring::ResponseParser::ParseError, Rejected => e
      record_failure(company, e.message, reply, run: run, prompt_version: prompt_version)
    end

    def record_failure(company, message, reply = nil, run: nil, prompt_version: Prompt::VERSION)
      company.draft_runs.create!(
        { status: "failed", error: message.to_s.truncate(500), pipeline_run: run }.merge(run_attributes(reply, prompt_version))
      )
    end

    private

    def accepted_variants(data)
      by_label = data["variants"].group_by { |variant| variant["label"] }
      duplicate = by_label.find { |_, list| list.size > 1 }
      raise Rejected, "duplicate variant: #{duplicate.first}" if duplicate

      variants = by_label.transform_values(&:first)
      REQUIRED.each { |label| require_valid!(label, variants[label]) }
      kept = REQUIRED.map { |label| variants[label] }
      founder = variants["founder_time"]
      kept << founder if founder && founder_supported?(data) && @validator.call(founder["body"]).empty?
      kept
    end

    def require_valid!(label, variant)
      raise Rejected, "#{label}: missing" unless variant

      problems = @validator.call(variant["body"])
      raise Rejected, "#{label}: #{problems.join(', ')}" if problems.any?
    end

    def founder_supported?(data)
      evidence = data["founder_time_evidence"].to_s.strip
      evidence.present? && evidence.downcase != NO_EVIDENCE
    end

    def persist(company, reply, data, variants, pipeline_run, prompt_version)
      Company.transaction do
        company.messages.where(status: "draft").destroy_all
        draft_run = company.draft_runs.create!(
          { status: "ok", raw: data, pipeline_run: pipeline_run }.merge(run_attributes(reply, prompt_version))
        )
        variants.each do |variant|
          company.messages.create!(
            contact: company.selected_contact, draft_run: draft_run, label: variant["label"], body: variant["body"].squish,
            evidence: variant["observation"], model: draft_run.model, prompt_version: prompt_version
          )
        end
        draft_run
      end
    end

    def run_attributes(reply, prompt_version)
      attrs = { model: Setting.get("models.drafting"), prompt_version: prompt_version }
      return attrs unless reply

      attrs.merge(tokens_in: reply.input_tokens, tokens_out: reply.output_tokens, cache_read_tokens: reply.cache_read_tokens,
                  cache_write_tokens: reply.cache_write_tokens, cost_usd: cost(reply))
    end

    # An unpriced model must never lose a paid result: record it at $0 and report loudly.
    def cost(reply)
      @pricing.cost(model: Setting.get("models.drafting"), input: reply.input_tokens, output: reply.output_tokens,
                    cache_read: reply.cache_read_tokens, cache_write: reply.cache_write_tokens,
                    cache_ttl: Setting.get("scoring.cache_ttl"))
    rescue Budget::Pricing::UnknownModel => e
      Rails.error.report(e, handled: true)
      0
    end
  end
end
