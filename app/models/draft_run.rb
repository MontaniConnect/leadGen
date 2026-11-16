# One drafting call for a company: its token usage, outcome and the messages it produced.
class DraftRun < ApplicationRecord
  STATUSES = %w[ok failed].freeze

  belongs_to :company
  belongs_to :pipeline_run, optional: true
  has_many :messages, dependent: :nullify

  validates :status, inclusion: { in: STATUSES }
end
