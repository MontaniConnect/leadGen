module Scoring
  # Fetches a finished batch and stores one evaluation per entry. Returns :pending if it hasn't ended.
  class BatchCollector
    def initialize(gateway:, recorder: Recorder.new)
      @gateway = gateway
      @recorder = recorder
    end

    def call(scoring_batch)
      return :collected if scoring_batch.collected?
      return :pending unless @gateway.batch_status(scoring_batch.anthropic_batch_id).ended

      counts = Hash.new(0)
      @gateway.batch_results(scoring_batch.anthropic_batch_id) do |entry|
        counts[store(entry, scoring_batch.pipeline_run) ? :succeeded : :errored] += 1
      end
      scoring_batch.update!(status: "collected", collected_at: Time.current,
                            succeeded: counts[:succeeded], errored: counts[:errored])
      scoring_batch.pipeline_run&.update!(status: "complete", finished_at: Time.current)
      :collected
    end

    private

    # Returns true when an ok evaluation was stored.
    def store(entry, run)
      company = Company.find_by(id: entry.custom_id.delete_prefix(BatchSubmitter::CUSTOM_ID_PREFIX))
      return false unless company

      evaluation = if entry.reply
        @recorder.call(company, entry.reply, run: run, batch: true)
      else
        @recorder.record_failure(company, "batch #{entry.status}: #{entry.error}".truncate(500), run: run, batch: true)
      end
      evaluation.status == "ok"
    end
  end
end
