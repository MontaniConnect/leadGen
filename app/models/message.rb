class Message < ApplicationRecord
  LABELS = %w[curious_question founder_time low_pressure_offer partnership].freeze
  LABEL_NAMES = {
    "curious_question" => "Curious question", "founder_time" => "Founder-time angle",
    "low_pressure_offer" => "Low-pressure offer", "partnership" => "Partnership"
  }.freeze
  # The three variants drafted for sales leads. "partnership" is only for staffing-firm partners.
  LEAD_LABELS = %w[curious_question founder_time low_pressure_offer].freeze
  STATUSES = %w[draft edited sent].freeze

  belongs_to :company
  belongs_to :contact, optional: true
  belongs_to :draft_run, optional: true

  before_validation { self.word_count = Drafting::MessageValidator.word_count(body) }

  def label_name = LABEL_NAMES.fetch(label)

  validates :label, inclusion: { in: LABELS }
  validates :status, inclusion: { in: STATUSES }
  validates :body, presence: true
end
