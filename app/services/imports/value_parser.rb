require "date"

module Imports
  # Forgiving parsers for Apollo's human-formatted cells.
  module ValueParser
    module_function

    def integer(value)
      digits = value.to_s.gsub(/[,\s]/, "")
      digits.match?(/\A-?\d+\z/) ? digits.to_i : nil
    end

    # "$1,200,000" or "1.2M" or "350K"
    def money(value)
      text = value.to_s.strip.delete("$,").upcase
      match = text.match(/\A(\d+(?:\.\d+)?)([KMB]?)\z/)
      return nil unless match

      multiplier = { "" => 1, "K" => 1_000, "M" => 1_000_000, "B" => 1_000_000_000 }[match[2]]
      (match[1].to_f * multiplier).round
    end

    def date(value)
      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end

    def text(value)
      value.to_s.strip.presence
    end
  end
end
