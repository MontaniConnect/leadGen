module Drafting
  class RequestBuilder
    def initialize(formatter: EvidenceFormatter.new, examples: -> { Outreach::ApprovedExamples.call })
      @formatter = formatter
      @examples = examples
    end

    def call(company)
      {
        model: Setting.get("models.drafting"),
        max_tokens: Setting.get("drafting.max_tokens"),
        system_: [ { type: "text", text: system_text, cache_control: { type: "ephemeral", ttl: Setting.get("scoring.cache_ttl") } } ],
        messages: [ { role: "user", content: @formatter.call(company) } ],
        output_config: { effort: Setting.get("drafting.effort"), format_: { type: "json_schema", schema: Schema.for_api } }
      }
    end

    # The cached instructions, plus any approved examples. Same inputs always give the same text.
    def system_text
      Prompt::SYSTEM.sub("{TARGET_WORDS}", Setting.get("drafting.target_words").to_s) + Prompt.examples_section(@examples.call)
    end

    def prompt_version = Prompt.version_for(@examples.call)
  end
end
