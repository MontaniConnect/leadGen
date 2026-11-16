module Partnering
  class RequestBuilder
    def initialize(formatter: EvidenceFormatter.new)
      @formatter = formatter
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

    def system_text = Prompt::SYSTEM.sub("{TARGET_WORDS}", Setting.get("drafting.target_words").to_s)
  end
end
