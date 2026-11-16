module Prefilter
  # Dashboard numbers: pass/fail totals and how many companies hit each fail reason.
  class Report
    def initialize(scope = Company.all)
      @scope = scope
    end

    def status_counts
      @scope.group(:prefilter_status).count
    end

    # { "employees_below_min" => 312, ... } most common first. A company can have several reasons.
    def reason_counts
      @scope.where(prefilter_status: "fail").pluck(:prefilter_reasons).flatten.tally.sort_by { |_, n| -n }.to_h
    end
  end
end
