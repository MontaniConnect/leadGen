# Scores every company awaiting evaluation, as the already-started PipelineRun `run_id`.
class ScoringRunJob < ApplicationJob
  queue_as :default

  def perform(run_id, gateway: nil)
    run = PipelineRun.find(run_id)
    gateway ||= Scoring::AnthropicGateway.from_environment
    Pipeline::ScoringRun.new(gateway: gateway, run: run, out: StringIO.new).call
  rescue StandardError => e
    run&.update(status: "failed", halted_reason: "#{e.class.name.demodulize}: #{e.message}".truncate(250), finished_at: Time.current) if run&.running?
    raise
  end
end
