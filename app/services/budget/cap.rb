module Budget
  # The one place the spending cap is changed (used by the CLI and the spend page).
  module Cap
    class Invalid < StandardError; end
    MAX = 100_000

    def self.set!(amount)
      value = Float(amount.to_s.delete("$,").strip)
      raise Invalid, "The cap must be more than $0 and at most $#{MAX}." unless value.positive? && value <= MAX

      Setting.set("budget.spending_cap_usd", value.round(2))
    rescue ArgumentError
      raise Invalid, "\"#{amount}\" is not a dollar amount."
    end
  end
end
