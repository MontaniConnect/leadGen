class Evaluation < ApplicationRecord
  STATUSES = %w[ok failed].freeze
  TIERS = %w[Hot Warm Cold].freeze
  CONFIDENCES = %w[High Medium Low].freeze

  belongs_to :company
  belongs_to :pipeline_run, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :tier, inclusion: { in: TIERS }, if: -> { status == "ok" }
  validates :confidence, inclusion: { in: CONFIDENCES }, if: -> { status == "ok" }

  scope :ok, -> { where(status: "ok") }
  scope :failed, -> { where(status: "failed") }
  # The latest successful evaluation per company. Use with the table name `evaluations` in scope.
  scope :current, lambda {
    ok.where("evaluations.id = (SELECT MAX(e2.id) FROM evaluations e2 " \
             "WHERE e2.company_id = evaluations.company_id AND e2.status = 'ok')")
  }
end
