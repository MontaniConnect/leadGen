module Scoring
  # Submits companies awaiting evaluation as Message Batches (half price, results within 24h).
  class BatchSubmitter
    CUSTOM_ID_PREFIX = "company-".freeze

    def initialize(gateway:, request_builder: RequestBuilder.new, batch_size: Setting.get("scoring.batch_size"),
                   guard: Budget::Guard.new)
      @gateway = gateway
      @request_builder = request_builder
      @batch_size = batch_size
      @guard = guard
    end

    # Returns the ScoringBatch records created. Each batch reserves its worst-case cost against the cap
    # until collected; a batch that would not fit raises Budget::Guard::CapReached and is not submitted.
    def call(companies = Company.awaiting_evaluation, run: nil)
      companies.includes(:pages).each_slice(@batch_size).map { |slice| submit(slice, run) }
    end

    private

    def submit(slice, run)
      entries = slice.map { |company| { custom_id: "#{CUSTOM_ID_PREFIX}#{company.id}", params: @request_builder.call(company) } }
      reserved = @guard.authorize_batch!(entries.map { |entry| entry[:params] })
      batch_id = @gateway.create_batch(entries)
      ScoringBatch.create!(anthropic_batch_id: batch_id, model: Setting.get("models.scoring"), requests_count: entries.size,
                           company_ids: slice.map(&:id), reserved_usd: reserved, pipeline_run: run)
    end
  end
end
