module Pipeline
  # Where the passed companies are in the pipeline, for the dashboard.
  class Status
    def initialize(passed: Company.prefilter_passed)
      @passed = passed
    end

    def passed = @passed.count
    def awaiting_fetch = @passed.where.not(domain: nil).where.not(id: Page.select(:company_id))
    def fetched = @passed.where(id: Page.select(:company_id)).count
    def awaiting_score = Company.awaiting_evaluation
    def awaiting_drafts = Company.awaiting_drafts
    def failed_evaluations = Company.where(id: Evaluation.failed.select(:company_id)).where.not(id: Evaluation.ok.select(:company_id)).count

    # { "Hot" => n, "Warm" => n, "Cold" => n } by each company's latest successful evaluation.
    def tiers
      counts = Evaluation.current.joins(:company).merge(@passed).group(:tier).count
      %w[Hot Warm Cold].index_with { |tier| counts.fetch(tier, 0) }
    end

    def drafted = Company.where(id: Message.select(:company_id)).count
    def last_run(kind) = PipelineRun.where(kind: kind).order(:id).last
    def running?(kind) = PipelineRun.active(kind).exists?
  end
end
