module Scoring
  # Builds the Messages API request for one company. Used as-is for direct calls and as the
  # `params` of a batch entry, so both paths send identical requests.
  class RequestBuilder
    def initialize(formatter: EvidenceFormatter.new)
      @formatter = formatter
    end

    def call(company)
      {
        model: Setting.get("models.scoring"),
        max_tokens: Setting.get("scoring.max_tokens"),
        system_: [ { type: "text", text: Prompt::SYSTEM, cache_control: cache_control } ],
        messages: [ { role: "user", content: @formatter.call(company) } ],
        output_config: { effort: Setting.get("scoring.effort"), format_: { type: "json_schema", schema: Schema.for_api } }
      }
    end

    private

    def cache_control
      { type: "ephemeral", ttl: Setting.get("scoring.cache_ttl") }
    end
  end
end
