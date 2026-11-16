module Outreach
  # Things the results suggest, for a person to review. Nothing here changes anything by itself:
  # the Results page offers an Approve button for defaults and examples, and the rule changes are advice only.
  #
  # Every suggestion needs min_sample sends behind each number it compares, and a gap of at least
  # min_difference_pts, because small samples are noisy. Variants are compared on RANDOMLY assigned sends
  # only, so favouring a winner later cannot bias the comparison.
  class Suggestions
    VariantDefault = Data.define(:dimension, :segment, :variant, :variant_name, :cells, :approved)
    Example = Data.define(:send_record, :text, :approved)
    RuleChange = Data.define(:title, :evidence, :how)

    def initialize(sends:, approvals: Approvals.new, segments: Segments.new, min_sample: Setting.get("results.min_sample"),
                   min_difference_pts: Setting.get("results.min_difference_pts"),
                   max_candidates: Setting.get("results.example_candidates"))
      @sends = sends
      @approvals = approvals
      @segments = segments
      @min_sample = min_sample
      @min_difference = min_difference_pts
      @max_candidates = max_candidates
    end

    def enough_data? = messaged.size >= @min_sample
    def messaged = @messaged ||= @sends.select(&:messaged?)

    def variant_defaults
      return [] unless enough_data?

      random = messaged.select { |record| record.assignment == "random" && record.variant }
      %w[tier title size score industry].flat_map do |dimension|
        random.group_by { |record| segments_for(record)[dimension] }.filter_map do |segment, group|
          variant_default(dimension, segment, group)
        end
      end
    end

    def example_candidates
      return [] unless enough_data?

      messaged.select(&:positive_reply)
              .sort_by { |record| [ record.call_booked ? 0 : 1, record.replied_at || Time.zone.at(2**31), record.id ] }
              .first(@max_candidates)
              .map { |record| Example.new(record, Anonymizer.call(record), @approvals.example_ids.include?(record.id)) }
    end

    def rule_changes
      return [] unless enough_data?

      tier_changes + size_changes + industry_changes
    end

    private

    def segments_for(record) = (@segment_cache ||= {})[record.id] ||= @segments.for(record)

    def variant_default(dimension, segment, group)
      return nil if segment == Segments::UNKNOWN

      eligible = group.group_by(&:variant).select { |_, list| list.size >= @min_sample }
      return nil if eligible.size < 2

      ranked = eligible.sort_by { |variant, list| [ -rate(list), -positive_rate(list), variant ] }
      (best, best_list), (_, runner_list) = ranked.first(2)
      return nil if (rate(best_list) - rate(runner_list)) * 100 < @min_difference

      cells = ranked.to_h { |variant, list| [ variant, Cell.new(list.count(&:replied), list.size) ] }
      VariantDefault.new(dimension: dimension, segment: segment, variant: best, variant_name: Message::LABEL_NAMES[best],
                         cells: cells, approved: @approvals.defaults["#{dimension}:#{segment}"] == best)
    end

    # Warm replying better than Hot (or Cold better than Warm) means the scores are not predicting replies.
    def tier_changes
      by_tier = messaged.group_by { |record| segments_for(record)["tier"] }
      [ %w[Hot Warm scoring.hot_min_score], %w[Warm Cold scoring.warm_min_score] ].filter_map do |higher, lower, setting|
        high = by_tier[higher].to_a
        low = by_tier[lower].to_a
        next unless high.size >= @min_sample && low.size >= @min_sample && (rate(low) - rate(high)) * 100 >= @min_difference

        RuleChange.new(
          title: "#{lower} leads are replying more than #{higher} leads",
          evidence: "#{lower}: #{count_text(low)}. #{higher}: #{count_text(high)}.",
          how: "The scores may not be separating good leads from average ones. Review the scoring prompt and #{setting} " \
               "(now #{Setting.get(setting)}). Compare reply rate by score band on this page before changing anything."
        )
      end
    end

    # The smallest or largest size band replying much worse than everyone else suggests moving that bound.
    def size_changes
      bands = Setting.get("results.size_bands")
      [ [ bands.first, "prefilter.min_employees", :raise_min ], [ bands.last, "prefilter.max_employees", :lower_max ] ].filter_map do |band, setting, kind|
        inside = messaged.select { |record| segments_for(record)["size"] == band["label"] }
        others = messaged - inside
        next unless worse?(inside, others)

        target = kind == :raise_min ? band["max"] + 1 : band["min"] - 1
        RuleChange.new(
          title: "Companies with #{band['label']} employees reply much less",
          evidence: "#{band['label']}: #{count_text(inside)}. All others: #{count_text(others)}.",
          how: "Consider changing #{setting} from #{Setting.get(setting)} to #{target} and re-running the prefilter. " \
               "This is a suggestion only."
        )
      end
    end

    def industry_changes
      by_industry = messaged.group_by { |record| segments_for(record)["industry"] }
      by_industry.filter_map do |industry, inside|
        next if industry == Segments::UNKNOWN

        others = messaged - inside
        next unless worse?(inside, others)

        RuleChange.new(
          title: "#{industry} companies reply much less",
          evidence: "#{industry}: #{count_text(inside)}. All others: #{count_text(others)}.",
          how: "If this holds as more sends come in, you could add \"#{industry.downcase}\" to prefilter.excluded_keywords. " \
               "This is a suggestion only."
        )
      end
    end

    def worse?(inside, others)
      inside.size >= @min_sample && others.size >= @min_sample && (rate(others) - rate(inside)) * 100 >= @min_difference
    end

    def rate(list) = list.empty? ? 0.0 : list.count(&:replied).to_f / list.size
    def positive_rate(list) = list.empty? ? 0.0 : list.count(&:positive_reply).to_f / list.size
    def count_text(list) = "#{list.count(&:replied)} of #{list.size} replied"
  end
end
