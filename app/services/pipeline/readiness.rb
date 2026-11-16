module Pipeline
  # Can a paid step be started right now? Returns the reason it can't, in words a person can act on, or nil.
  # Also gives the cost figures shown on the button. Never calls a paid endpoint.
  class Readiness
    STEPS = { score: "score", draft: "draft", partner: "draft" }.freeze

    def initialize(step, status: Status.new, ledger: Budget::Ledger.new, dry_run: Budget::DryRun.new,
                   guard: Budget::Guard.new, partner_builder: Partnering::RequestBuilder.new)
      @step = step.to_sym
      @status = status
      @ledger = ledger
      @dry_run = dry_run
      @guard = guard
      @partner_builder = partner_builder
    end

    def problem
      return "A #{@step} run is already in progress. Wait for it to finish." if @status.running?(STEPS.fetch(@step))
      return "Nothing to #{@step} right now." if count.zero?
      return "The Anthropic API key is not set. Save it in the credentials first." unless Scoring::ApiKey.present?
      return "No spending cap is set. Set one on the Spend page first." unless @ledger.cap

      nil
    end

    def count
      @count ||= awaiting.count
    end

    # The estimate for exactly the companies the step would handle.
    def stage
      @stage ||= begin
        return partner_stage if @step == :partner

        result = @dry_run.call(scope: Company.all)
        @step == :score ? result.stages.first : result.stages.last
      end
    end

    def awaiting
      { score: -> { @status.awaiting_score }, draft: -> { @status.awaiting_drafts }, partner: -> { Company.awaiting_partner_drafts } }.fetch(@step).call
    end

    def expected_cost = stage.expected_cost
    def worst_case_cost = stage.worst_case_cost

    private

    PartnerStage = Data.define(:expected_cost, :worst_case_cost)

    # Partnership drafts are not part of the DryRun: priced here from their real requests.
    def partner_stage
      requests = Company.awaiting_partner_drafts.includes(:pages, :selected_contact, :evaluations).map { |company| @partner_builder.call(company) }
      estimator = Budget::TokenEstimator.new
      inputs = requests.sum { |request| estimator.count(request) }
      expected = requests.empty? ? BigDecimal(0) : Budget::Pricing.new.cost(model: Setting.get("models.drafting"), input: inputs,
                                                                          output: requests.size * Setting.get("estimates.partner_output_tokens"))
      PartnerStage.new(expected, requests.sum(BigDecimal(0)) { |request| @guard.worst_case(request) })
    end
  end
end
