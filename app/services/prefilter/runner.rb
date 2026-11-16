module Prefilter
  # Applies the evaluator to companies and stores the verdict. Safe to re-run after rule changes.
  class Runner
    def initialize(evaluator: Evaluator.new(Rules.from_settings), scope: Company.all)
      @evaluator = evaluator
      @scope = scope
    end

    def call
      tally = Hash.new(0)
      @scope.find_each do |company|
        result = @evaluator.call(company)
        company.update!(
          prefilter_status: result.status, prefilter_reasons: result.reasons,
          prefilter_boosts: result.boosts, prefilter_score: result.score, prefiltered_at: Time.current
        )
        tally[result.status] += 1
      end
      tally
    end
  end
end
