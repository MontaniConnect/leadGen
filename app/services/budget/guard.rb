module Budget
  # Stops paid calls before they are made. A call is allowed only if (spent + reserved + the worst case
  # for this call) stays within the cap. No cap set, or an unpriced model, also blocks: fail closed.
  class Guard
    class CapReached < StandardError; end
    class NoCapSet < CapReached
      def initialize(message = "No spending cap is set. Set one first, for example: bin/rails 'budget:cap[25]'")
        super
      end
    end

    def initialize(ledger: Ledger.new, pricing: Pricing.new, estimator: TokenEstimator.new)
      @ledger = ledger
      @pricing = pricing
      @estimator = estimator
    end

    # Raises CapReached (or NoCapSet) unless this one request fits under the cap.
    def authorize!(request, batch: false)
      authorize_amount!(worst_case(request, batch: batch))
    end

    # For a whole batch: returns the total worst-case dollars to reserve for it.
    def authorize_batch!(requests)
      total = requests.sum(BigDecimal(0)) { |request| worst_case(request, batch: true) }
      authorize_amount!(total)
      total
    end

    # Highest this request can cost: all input uncached at full price plus a reply that fills max_tokens.
    def worst_case(request, batch: false)
      @pricing.cost(model: request[:model], input: @estimator.count(request), output: request[:max_tokens], batch: batch)
    end

    private

    def authorize_amount!(amount)
      cap = @ledger.cap
      raise NoCapSet unless cap

      committed = @ledger.committed
      return amount if committed + amount <= cap

      raise CapReached, "Spending cap reached: #{money(committed)} spent or reserved, " \
                        "this call could cost up to #{money(amount)}, cap is #{money(cap)}."
    end

    def money(amount) = amount < 1 ? format("$%.4f", amount) : format("$%.2f", amount)
  end
end
