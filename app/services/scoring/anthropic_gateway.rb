require "anthropic"

module Scoring
  # The only class that talks to the Anthropic SDK. Inject a fake with the same four methods in tests.
  class AnthropicGateway
    class MissingApiKey < StandardError; end

    def self.from_environment(env: ENV, credentials: Rails.application.credentials)
      key = env["ANTHROPIC_API_KEY"].presence || credentials.dig(:anthropic, :api_key)
      raise MissingApiKey, "Set ANTHROPIC_API_KEY or credentials anthropic.api_key" if key.blank?

      new(Anthropic::Client.new(api_key: key))
    end

    def initialize(client)
      @client = client
    end

    FALLBACK_BETA = :"server-side-fallback-2026-07-01"

    # fallbacks: true retries a declined request on a server-chosen substitute model (beta endpoint).
    def message(request, fallbacks: false)
      response = if fallbacks
        @client.beta.messages.create(**request, betas: [ FALLBACK_BETA ], fallbacks: :default)
      else
        @client.messages.create(**request)
      end
      reply_from(response)
    end

    # Exact input-token count for a request (free; counts system, messages and output schema).
    def count_tokens(request)
      @client.messages.count_tokens(**request.slice(:model, :system_, :messages, :output_config)).input_tokens
    end

    def create_batch(entries)
      batch = @client.messages.batches.create(requests: entries)
      batch.id
    end

    def batch_status(batch_id)
      batch = @client.messages.batches.retrieve(batch_id)
      BatchStatus.new(id: batch.id, ended: batch.processing_status == :ended,
                      succeeded: batch.request_counts.succeeded, errored: batch.request_counts.errored)
    end

    def batch_results(batch_id)
      @client.messages.batches.results_streaming(batch_id).each do |entry|
        yield batch_entry_from(entry)
      end
    end

    private

    def batch_entry_from(entry)
      result = entry.result
      case result.type
      when :succeeded then BatchEntry.new(entry.custom_id, "succeeded", reply_from(result.message), nil)
      when :errored then BatchEntry.new(entry.custom_id, "errored", nil, result.error.to_json)
      else BatchEntry.new(entry.custom_id, result.type.to_s, nil, result.type.to_s)
      end
    end

    def reply_from(message)
      usage = message.usage
      Reply.new(
        text: message.content.select { |block| block.type == :text }.map(&:text).join,
        stop_reason: message.stop_reason.to_s,
        refusal_category: (message.respond_to?(:stop_details) ? message.stop_details&.category&.to_s : nil),
        input_tokens: usage.input_tokens.to_i, output_tokens: usage.output_tokens.to_i,
        cache_read_tokens: usage.cache_read_input_tokens.to_i, cache_write_tokens: usage.cache_creation_input_tokens.to_i
      )
    end
  end
end
