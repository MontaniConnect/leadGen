module Scoring
  # Plain value object so nothing outside AnthropicGateway depends on SDK types.
  Reply = Data.define(:text, :stop_reason, :refusal_category, :input_tokens, :output_tokens,
                      :cache_read_tokens, :cache_write_tokens)
end
