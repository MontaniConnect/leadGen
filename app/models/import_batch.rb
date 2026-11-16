class ImportBatch < ApplicationRecord
  KINDS = %w[accounts people replies].freeze

  has_many :companies, dependent: :nullify

  validates :kind, inclusion: { in: KINDS }

  def rows_unchanged
    rows_total - rows_created - rows_updated - rows_skipped
  end
end
