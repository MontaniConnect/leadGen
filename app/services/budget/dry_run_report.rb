module Budget
  # Plain-text table for a DryRun::Result.
  class DryRunReport
    def initialize(result)
      @result = result
    end

    def to_s
      lines = [ "DRY RUN: no paid API calls were made.",
                "Counting: #{@result.counting}. Pricing: #{@result.batch ? 'batch (half price)' : 'direct calls'}.", "" ]
      lines << format("%-9s %-18s %-22s %12s %12s %10s %11s", "Stage", "Model", "Companies", "Input tok", "Output tok", "Expected", "Worst case")
      @result.stages.each { |stage| lines << stage_line(stage) }
      lines << format("%-9s %-18s %-22s %12s %12s %10s %11s", "Total", "", "", "", "", money(@result.expected_cost), money(@result.worst_case_cost))
      lines.concat([ "", cap_line, fit_line ])
      lines.join("\n")
    end

    private

    def stage_line(stage)
      companies = stage.projected.positive? ? "#{stage.companies} (#{stage.projected} projected)" : stage.companies.to_s
      format("%-9s %-18s %-22s %12s %12s %10s %11s", stage.name, stage.model, companies, number(stage.input_tokens),
             number(stage.expected_output_tokens), money(stage.expected_cost), money(stage.worst_case_cost))
    end

    def cap_line
      return "Cap: NOT SET. Paid runs are blocked until you set one: bin/rails 'budget:cap[25]'" unless @result.cap

      "Cap: #{money(@result.cap)}. Already spent or reserved: #{money(@result.committed)}. Remaining: #{money(@result.remaining)}."
    end

    def fit_line
      return "Projected rows use the estimates.* settings until pages are fetched and Hot leads exist." unless @result.cap

      verdict = @result.fits? ? "YES, even if every reply is as long as allowed and nothing is cached." : "NO. The run would be halted by the cap."
      "Worst case fits within the cap: #{verdict}\nProjected rows use the estimates.* settings until pages are fetched and Hot leads exist."
    end

    def money(amount) = amount < 1 ? format("$%.4f", amount) : format("$%.2f", amount)
    def number(value) = value.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
  end
end
