module Budget
  # Local, offline input-token estimate for a request (system + messages + output schema).
  # It uses a pessimistic characters-per-token ratio, so it errs high. Use ExactTokenCounter for the real number.
  class TokenEstimator
    def initialize(chars_per_token: Setting.get("estimates.chars_per_token"))
      @chars_per_token = chars_per_token.to_f
    end

    def count(request)
      count_text(request_text(request))
    end

    def count_text(text)
      (text.to_s.length / @chars_per_token).ceil
    end

    private

    def request_text(request)
      system_text = Array(request[:system_]).map { |block| block[:text] }.join("\n")
      messages = request[:messages].map { |message| message[:content].is_a?(String) ? message[:content] : message[:content].to_json }
      schema = request.dig(:output_config, :format_, :schema).to_json
      [ system_text, *messages, schema ].join("\n")
    end
  end
end
