require "json"

module Scoring
  # Turns a Reply into validated data (against the given schema), or raises ParseError with a short reason.
  class ResponseParser
    class ParseError < StandardError; end

    def initialize(schema: Scoring::Schema)
      @schema = schema
    end

    def call(reply)
      raise ParseError, "refusal (#{reply.refusal_category || 'unspecified'})" if reply.stop_reason == "refusal"
      raise ParseError, "output truncated at max_tokens" if reply.stop_reason == "max_tokens"

      data = parse_json(reply.text)
      problems = @schema.errors_for(data)
      raise ParseError, "schema: #{problems.first(3).join('; ')}" if problems.any?

      data
    end

    private

    def parse_json(text)
      JSON.parse(text.to_s)
    rescue JSON::ParserError => e
      raise ParseError, "invalid JSON: #{e.message.truncate(120)}"
    end
  end
end
