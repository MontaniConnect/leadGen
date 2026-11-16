require "bigdecimal"

module Budget
  # Turns token counts into dollars using the prices in Settings (pricing.*).
  class Pricing
    class UnknownModel < StandardError; end

    MILLION = BigDecimal(1_000_000)

    def initialize(models: Setting.get("pricing.models"), cache_read_multiplier: Setting.get("pricing.cache_read_multiplier"),
                   cache_write_multipliers: Setting.get("pricing.cache_write_multipliers"),
                   batch_multiplier: Setting.get("pricing.batch_multiplier"))
      @models = models || {}
      @cache_read_multiplier = BigDecimal(cache_read_multiplier.to_s)
      @cache_write_multipliers = cache_write_multipliers
      @batch_multiplier = BigDecimal(batch_multiplier.to_s)
    end

    # input = uncached input tokens only (what the API reports as input_tokens).
    def cost(model:, input:, output:, cache_read: 0, cache_write: 0, cache_ttl: "1h", batch: false)
      price_in, price_out = rates(model)
      write_multiplier = BigDecimal(@cache_write_multipliers.fetch(cache_ttl).to_s)
      total = (input * price_in) + (output * price_out) +
              (cache_read * price_in * @cache_read_multiplier) +
              (cache_write * price_in * write_multiplier)
      total /= MILLION
      batch ? total * @batch_multiplier : total
    end

    def known?(model) = @models.key?(model)

    private

    def rates(model)
      entry = @models[model]
      raise UnknownModel, "No price set for #{model}. Add it under pricing.models in the settings." unless entry

      [ BigDecimal(entry.fetch("input").to_s), BigDecimal(entry.fetch("output").to_s) ]
    end
  end
end
