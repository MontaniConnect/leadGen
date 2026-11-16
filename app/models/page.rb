class Page < ApplicationRecord
  KINDS = %w[home about careers blog].freeze
  # Outcomes that are not worth retrying until the refetch window passes.
  SETTLED_STATUSES = %w[ok empty not_found blocked].freeze

  belongs_to :company

  validates :kind, inclusion: { in: KINDS }

  def fresh?(days:, now: Time.current)
    fetched_at.present? && fetched_at > now - days.days && SETTLED_STATUSES.include?(status)
  end
end
