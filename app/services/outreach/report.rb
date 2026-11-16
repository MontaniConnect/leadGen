module Outreach
  # Results of the outreach so far. Every rate is a Cell, so the count behind it is always available
  # and the view can refuse to show a percentage from too small a sample.
  #
  # Rates are computed over sends whose message was actually sent (the denominator is "messages sent").
  class Report
    Row = Data.define(:label, :sent, :reply, :positive)
    FunnelStage = Data.define(:label, :cell, :basis)

    TIER_ORDER = %w[Hot Warm Cold].freeze

    attr_reader :min_sample

    def initialize(sends: OutreachSend.all.to_a, segments: Segments.new, min_sample: Setting.get("results.min_sample"))
      @sends = sends
      @segments = segments
      @min_sample = min_sample
    end

    def reliable?(cell) = cell.total >= min_sample
    def empty? = @sends.empty?
    def messaged = @messaged ||= @sends.select(&:messaged?)

    # Each stage counted against the one before it, so the drop-off is visible.
    def funnel
      accepted = @sends.count(&:connection_accepted)
      [
        FunnelStage.new("Connection requests sent", Cell.new(@sends.size, @sends.size), "all requests"),
        FunnelStage.new("Connection accepted", Cell.new(accepted, @sends.size), "of requests sent"),
        FunnelStage.new("Message sent", Cell.new(messaged.size, accepted), "of accepted"),
        FunnelStage.new("Replied", Cell.new(messaged.count(&:replied), messaged.size), "of messages sent"),
        FunnelStage.new("Positive reply", Cell.new(messaged.count(&:positive_reply), messaged.count(&:replied)), "of replies"),
        FunnelStage.new("Call booked", Cell.new(messaged.count(&:call_booked), messaged.count(&:positive_reply)), "of positive replies")
      ]
    end

    # dimension: "variant", "tier", "title", "size", "score" or "industry".
    def breakdown(dimension)
      groups = messaged.group_by { |record| segment(record, dimension) }.compact_blank
      groups.delete(nil)
      rows = groups.map { |label, list| row(label, list) }
      rows.sort_by { |entry| [ order_index(dimension, entry.label), -entry.sent.total, entry.label ] }
    end

    private

    def row(label, list)
      Row.new(label: label, sent: Cell.new(list.size, list.size), reply: Cell.new(list.count(&:replied), list.size),
              positive: Cell.new(list.count(&:positive_reply), list.size))
    end

    def segment(record, dimension)
      return (Message::LABEL_NAMES[record.variant] if record.variant) if dimension == "variant"

      @segments.for(record)[dimension]
    end

    def order_index(dimension, label)
      list = case dimension
      when "variant" then Message::LABEL_NAMES.values
      when "tier" then TIER_ORDER
      when "title" then Setting.get("results.title_labels") + [ Segments::UNKNOWN ]
      when "size" then Setting.get("results.size_bands").map { |band| band["label"] } + [ "Outside range", Segments::UNKNOWN ]
      when "score" then Segments::SCORE_BANDS.map(&:last) + [ Segments::UNKNOWN ]
      else []
      end
      list.index(label) || list.size
    end
  end
end
