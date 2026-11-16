module Scoring
  # Hot: a top score at or above hot_min with enough confidence.
  # Warm: a score at or above warm_min, or a hot-level score with low confidence.
  # Cold: everything else, and always Cold when the company is disqualified.
  class TierRule
    def initialize(hot_min: Setting.get("scoring.hot_min_score"), warm_min: Setting.get("scoring.warm_min_score"),
                   hot_confidences: Setting.get("scoring.hot_confidences"))
      @hot_min = hot_min
      @warm_min = warm_min
      @hot_confidences = hot_confidences
    end

    def call(staffing:, automation:, confidence:, disqualified: false)
      return "Cold" if disqualified

      best = [ staffing, automation ].max
      return "Hot" if best >= @hot_min && @hot_confidences.include?(confidence)
      return "Warm" if best >= @warm_min

      "Cold"
    end
  end
end
