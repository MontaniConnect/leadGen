module Budget
  # One-paragraph description of a PipelineRun's tokens and cost.
  class RunSummary
    def initialize(run)
      @run = run
    end

    def to_s
      totals = @run.totals
      detail = "#{totals[:calls]} calls (#{totals[:failed]} failed), #{number(totals[:input_tokens])} input + " \
               "#{number(totals[:output_tokens])} output tokens, cache read #{number(totals[:cache_read_tokens])} / " \
               "write #{number(totals[:cache_write_tokens])}, cost #{format('$%.4f', totals[:cost_usd])}"
      line = "Run ##{@run.id} (#{@run.kind}): #{@run.status}. #{detail}"
      @run.halted_reason ? "#{line}\n#{@run.halted_reason}" : line
    end

    private

    def number(value) = value.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
  end
end
