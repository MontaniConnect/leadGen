module Partnering
  # Turns a reply into a DraftRun plus one "partnership" Message, with the same hard checks as lead messages
  # (50 words, ends with a question, no flattery or boilerplate). Unedited drafts are replaced on a re-draft;
  # edited and sent messages are kept.
  class Recorder < Drafting::Recorder
    def initialize(parser: Scoring::ResponseParser.new(schema: Schema), validator: Drafting::MessageValidator.new,
                   pricing: Budget::Pricing.new)
      super
    end

    def call(company, reply, run: nil)
      data = @parser.call(reply)
      problems = @validator.call(data["body"])
      raise Rejected, "partnership: #{problems.join(', ')}" if problems.any?

      persist_partner(company, reply, data, run)
    rescue Scoring::ResponseParser::ParseError, Rejected => e
      record_failure(company, e.message, reply, run: run, prompt_version: Prompt::VERSION)
    end

    private

    def persist_partner(company, reply, data, pipeline_run)
      Company.transaction do
        company.messages.where(label: "partnership", status: "draft").destroy_all
        draft_run = company.draft_runs.create!({ status: "ok", raw: data, pipeline_run: pipeline_run }.merge(run_attributes(reply, Prompt::VERSION)))
        company.messages.create!(contact: company.selected_contact, draft_run: draft_run, label: "partnership", body: data["body"].squish,
                                 evidence: data["observation"], model: draft_run.model, prompt_version: Prompt::VERSION)
        draft_run
      end
    end
  end
end
