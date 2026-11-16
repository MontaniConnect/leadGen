module Pipeline
  # Scores the companies awaiting evaluation as one tracked run. Stops cleanly when the spending cap
  # would be exceeded. `scope` narrows the companies (the pilot uses it).
  class ScoringRun
    def initialize(gateway:, scope: Company.all, limit: nil, run: nil, scorer: nil, out: $stdout)
      @scorer = scorer || Scoring::CompanyScorer.new(gateway: gateway)
      @scope = scope
      @limit = limit
      @run = run
      @out = out
    end

    def call
      work = lambda do |tracked|
        companies.each do |company|
          evaluation = @scorer.call(company, run: tracked)
          @out.puts describe(company, evaluation) if evaluation
        end
      end
      run = @run ? PipelineRun.run_with(@run, &work) : PipelineRun.track("score", &work)
      @out.puts Budget::RunSummary.new(run)
      run
    end

    private

    def companies
      Company.awaiting_evaluation.where(id: @scope.select(:id)).includes(:pages)
             .order(prefilter_score: :desc, id: :asc).limit(@limit)
    end

    def describe(company, evaluation)
      return "#{company.name}: FAILED #{evaluation.error}" unless evaluation.status == "ok"

      "#{company.name}: #{evaluation.tier} (S#{evaluation.staffing_score}/A#{evaluation.automation_score}, #{evaluation.confidence})"
    end
  end
end
