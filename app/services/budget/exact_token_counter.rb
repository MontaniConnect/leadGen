module Budget
  # Counts input tokens with the API's free count_tokens endpoint (exact for the request's model).
  class ExactTokenCounter
    def initialize(gateway:)
      @gateway = gateway
    end

    def count(request)
      @gateway.count_tokens(request)
    end
  end
end
