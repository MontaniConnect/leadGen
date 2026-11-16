# Polls one scoring batch and re-schedules itself until the batch has ended and been collected.
class CollectScoringBatchJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound
  POLL_INTERVAL = 5.minutes

  def perform(scoring_batch_id, gateway: Scoring::AnthropicGateway.from_environment)
    batch = ScoringBatch.find(scoring_batch_id)
    result = Scoring::BatchCollector.new(gateway: gateway).call(batch)
    self.class.set(wait: POLL_INTERVAL).perform_later(scoring_batch_id) if result == :pending
  end
end
