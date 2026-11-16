module Budget
  # What has been spent, and what is committed to be spent, according to the recorded calls.
  class Ledger
    def spent
      Evaluation.sum(:cost_usd) + DraftRun.sum(:cost_usd)
    end

    # Worst-case cost of batches submitted but not yet collected.
    def reserved
      ScoringBatch.where(collected_at: nil).sum(:reserved_usd)
    end

    def committed = spent + reserved

    def cap
      value = Setting.get("budget.spending_cap_usd")
      value && BigDecimal(value.to_s)
    end

    def remaining
      cap && (cap - committed)
    end
  end
end
