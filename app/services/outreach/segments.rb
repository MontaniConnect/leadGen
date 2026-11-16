module Outreach
  # Which segment a lead falls in along each dimension. Works on anything with the snapshot fields
  # (a saved send, or a send being built). Used to group results and to look up approved defaults.
  class Segments
    UNKNOWN = "Unknown".freeze
    SCORE_BANDS = [ [ 9, "9-10" ], [ 7, "7-8" ], [ 5, "5-6" ], [ 1, "1-4" ] ].freeze
    # Most specific first: the order approved defaults are looked up in.
    PRECEDENCE = %w[title size tier score industry].freeze

    def initialize(ranker: Contacts::TitleRanker.from_settings, size_bands: Setting.get("results.size_bands"),
                   title_labels: Setting.get("results.title_labels"))
      @ranker = ranker
      @size_bands = size_bands
      @title_labels = title_labels
    end

    # { "tier" => "Hot", "title" => "CEO / Founder", ... } with string keys and values.
    def for(record)
      {
        "tier" => record.tier.presence || UNKNOWN, "title" => title_bucket(record.contact_title),
        "size" => size_band(record.employee_count), "industry" => record.industry.presence || UNKNOWN,
        "score" => score_band(record)
      }
    end

    def title_bucket(title)
      return UNKNOWN if title.blank?

      rank = @ranker.rank(title)
      rank ? @title_labels.fetch(rank, @title_labels.last) : @title_labels.last
    end

    def size_band(count)
      return UNKNOWN unless count

      band = @size_bands.find { |entry| count.between?(entry["min"], entry["max"]) }
      band ? band["label"] : "Outside range"
    end

    def score_band(record)
      best = [ record.staffing_score, record.automation_score ].compact.max
      return UNKNOWN unless best

      SCORE_BANDS.find { |minimum, _| best >= minimum }&.last || UNKNOWN
    end
  end
end
