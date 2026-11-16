# One Anthropic Message Batch of company evaluations, tracked until its results are collected.
class ScoringBatch < ApplicationRecord
  belongs_to :pipeline_run, optional: true

  validates :anthropic_batch_id, presence: true, uniqueness: true

  def collected? = collected_at.present?
end
