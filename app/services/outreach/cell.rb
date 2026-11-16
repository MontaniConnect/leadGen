module Outreach
  # "count of total": the evidence behind every rate, kept so a percentage is never shown without its sample.
  Cell = Data.define(:count, :total) do
    def rate = total.zero? ? nil : count.to_f / total
    def to_s = "#{count} of #{total}"
  end
end
