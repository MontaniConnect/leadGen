module Budget
  # Estimates what the next scoring and drafting steps would cost, WITHOUT calling any paid endpoint.
  #
  # Companies that already have a built request (fetched pages / Hot with an evaluation) are counted from
  # that real request. Companies not far enough along yet are projected from the estimates.* settings.
  # Two numbers per stage: expected (prefix cached, typical replies) and worst case (nothing cached,
  # every reply fills max_tokens), which is what the spending cap guard uses.
  class DryRun
    Stage = Data.define(:name, :model, :companies, :projected, :input_tokens, :expected_output_tokens,
                        :max_output_tokens, :expected_cost, :worst_case_cost)
    Result = Data.define(:stages, :batch, :cap, :committed, :counting) do
      def expected_cost = stages.sum(BigDecimal(0), &:expected_cost)
      def worst_case_cost = stages.sum(BigDecimal(0), &:worst_case_cost)
      def remaining = cap && (cap - committed)
      def fits? = !remaining.nil? && worst_case_cost <= remaining
    end

    def initialize(counter: TokenEstimator.new, prefix_estimator: TokenEstimator.new, pricing: Pricing.new, ledger: Ledger.new,
                   scoring_builder: Scoring::RequestBuilder.new, drafting_builder: Drafting::RequestBuilder.new,
                   sample_size: nil)
      @counter = counter
      @prefix_estimator = prefix_estimator
      @pricing = pricing
      @ledger = ledger
      @scoring_builder = scoring_builder
      @drafting_builder = drafting_builder
      @sample_size = sample_size
    end

    def call(scope: Company.all, limit: nil, batch: false)
      scoring = scoring_stage(scope, limit, batch)
      drafting = drafting_stage(scope, scoring, limit, batch)
      Result.new(stages: [ scoring, drafting ], batch: batch, cap: @ledger.cap, committed: @ledger.committed,
                 counting: @sample_size ? "exact (API count_tokens, #{@sample_size} sampled per stage)" : "local estimate (errs high)")
    end

    private

    def scoring_stage(scope, limit, batch)
      ids = scope.select(:id)
      real = Company.awaiting_evaluation.where(id: ids).includes(:pages).order(:id).limit(limit).to_a
      not_fetched = Company.prefilter_passed.where(id: ids).where.not(id: Page.select(:company_id))
                           .where.not(id: Evaluation.ok.select(:company_id)).count
      projected = limit ? [ [ limit - real.size, 0 ].max, not_fetched ].min : not_fetched
      build_stage("Scoring", Setting.get("models.scoring"), real.map { |company| @scoring_builder.call(company) },
                  projected, Setting.get("estimates.scoring_input_tokens"), Setting.get("estimates.scoring_output_tokens"),
                  Setting.get("scoring.max_tokens"), Scoring::Prompt::SYSTEM, batch)
    end

    def drafting_stage(scope, scoring, limit, batch)
      ids = scope.select(:id)
      real = Company.awaiting_drafts.where(id: ids).includes(:pages, :selected_contact, :evaluations).order(:id).limit(limit).to_a
      expected_drafted = (scoring.companies * Setting.get("estimates.drafted_share").to_f).ceil
      build_stage("Drafting", Setting.get("models.drafting"), real.map { |company| @drafting_builder.call(company) },
                  expected_drafted, Setting.get("estimates.drafting_input_tokens"), Setting.get("estimates.drafting_output_tokens"),
                  Setting.get("drafting.max_tokens"), @drafting_builder.system_text, batch)
    end

    def build_stage(name, model, requests, projected, projected_input, expected_output, max_output, prefix_text, batch)
      count = requests.size + projected
      inputs = input_tokens(requests) + (projected * projected_input)
      prefix = [ @prefix_estimator.count_text(prefix_text), 0 ].max
      Stage.new(
        name: name, model: model, companies: count, projected: projected, input_tokens: inputs,
        expected_output_tokens: count * expected_output, max_output_tokens: count * max_output,
        expected_cost: expected_cost(model, count, inputs, prefix, expected_output, batch),
        worst_case_cost: count.zero? ? BigDecimal(0) : @pricing.cost(model: model, input: inputs, output: count * max_output, batch: batch)
      )
    end

    # The shared instructions are written to the cache once and read for every later call.
    def expected_cost(model, count, inputs, prefix, expected_output, batch)
      return BigDecimal(0) if count.zero?

      cached = [ prefix, inputs / count ].min
      @pricing.cost(model: model, input: inputs - (count * cached), output: count * expected_output,
                    cache_read: (count - 1) * cached, cache_write: cached,
                    cache_ttl: Setting.get("scoring.cache_ttl"), batch: batch)
    end

    # Counts every request, or (exact mode) samples a few and scales the average up.
    def input_tokens(requests)
      return 0 if requests.empty?
      return requests.sum { |request| @counter.count(request) } unless @sample_size && requests.size > @sample_size

      sample = requests.first(@sample_size)
      (sample.sum { |request| @counter.count(request) } * requests.size / sample.size.to_f).ceil
    end
  end
end
