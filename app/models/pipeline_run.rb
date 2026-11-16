# One execution of a paid step (scoring, drafting or a scoring batch) with its token and cost totals.
class PipelineRun < ApplicationRecord
  KINDS = %w[score draft score_batch].freeze
  STATUSES = %w[running complete halted failed].freeze

  has_many :evaluations, dependent: :nullify
  has_many :draft_runs, dependent: :nullify
  has_many :scoring_batches, dependent: :nullify

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  # Runs a block as a tracked run. A reached cap is a normal stop ("halted"), not an error.
  def self.track(kind)
    run = create!(kind: kind, started_at: Time.current)
    yield run
    run.update!(status: "complete", finished_at: Time.current)
    run
  rescue Budget::Guard::CapReached => e
    run.update!(status: "halted", halted_reason: e.message.truncate(250), finished_at: Time.current)
    run
  rescue StandardError => e
    run&.update!(status: "failed", halted_reason: "#{e.class.name.demodulize}: #{e.message}".truncate(250), finished_at: Time.current)
    raise
  end

  def calls
    records.sum(&:size)
  end

  def totals
    sources = records.flatten
    {
      calls: sources.size, failed: sources.count { |record| record.status == "failed" },
      input_tokens: sources.sum { |record| record.tokens_in.to_i }, output_tokens: sources.sum { |record| record.tokens_out.to_i },
      cache_read_tokens: sources.sum(&:cache_read_tokens), cache_write_tokens: sources.sum(&:cache_write_tokens),
      cost_usd: sources.sum(BigDecimal(0), &:cost_usd)
    }
  end

  private

  def records
    [ evaluations.to_a, draft_runs.to_a ]
  end
end
