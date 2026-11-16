module Pipeline
  # Submits scoring batches under one run. The run stays "running" until its batches are collected.
  # A batch whose worst case does not fit under the cap is not submitted and the run is marked halted.
  class BatchSubmission
    def initialize(gateway:, scope: Company.all, submitter: nil, out: $stdout)
      @submitter = submitter || Scoring::BatchSubmitter.new(gateway: gateway)
      @scope = scope
      @out = out
    end

    def call
      run = PipelineRun.create!(kind: "score_batch", started_at: Time.current)
      batches = @submitter.call(Company.awaiting_evaluation.where(id: @scope.select(:id)), run: run)
      batches.each { |batch| @out.puts "submitted #{batch.anthropic_batch_id}: #{batch.requests_count} companies, reserved #{format('$%.4f', batch.reserved_usd)}" }
      run.update!(status: "complete", finished_at: Time.current) if batches.empty?
      @out.puts "nothing to score" if batches.empty?
      run
    rescue Budget::Guard::CapReached => e
      run.update!(status: "halted", halted_reason: e.message.truncate(250), finished_at: Time.current)
      @out.puts e.message
      run
    end
  end
end
