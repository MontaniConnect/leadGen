# One outreach to one lead, from the LinkedIn connection request through the reply.
# (Named OutreachSend because a model called Send would shadow Ruby's own Object#send.)
#
# Lifecycle: created when the connection request is marked sent (the variant is assigned and the lead is
# snapshotted), then connection_accepted, then the message is sent (sent_body is the exact text), then the reply.
class OutreachSend < ApplicationRecord
  self.table_name = "sends"

  ASSIGNMENTS = %w[random manual suggested].freeze
  REPLY_FLAGS = {
    "replied" => { replied: true, positive_reply: false, call_booked: false },
    "interested" => { replied: true, positive_reply: true, call_booked: false },
    "call_booked" => { replied: true, positive_reply: true, call_booked: true },
    "not_a_fit" => { replied: true, positive_reply: false, call_booked: false },
    "no_reply" => { replied: false, positive_reply: false, call_booked: false }
  }.freeze
  CLEARED = { replied: false, positive_reply: false, call_booked: false }.freeze

  belongs_to :company
  belongs_to :contact, optional: true
  belongs_to :message, optional: true

  before_validation :normalize

  validates :assignment, inclusion: { in: ASSIGNMENTS }
  validates :variant, inclusion: { in: Message::LABELS }, allow_nil: true
  validates :company_id, uniqueness: true
  validates :variant, :sent_body, presence: true, if: -> { sent_at.present? }

  scope :messaged, -> { where.not(sent_at: nil) }

  def messaged? = sent_at.present?

  # Sets the reply flags from a reply result key; blank clears them. replied_at is set when a reply first appears.
  def record_reply_result!(result, at: Time.current)
    flags = REPLY_FLAGS.fetch(result.to_s) { CLEARED }
    update!(flags.merge(replied_at: (replied_at || at if flags[:replied])))
  end

  # The flags reduced back to the reply result key the lead screen shows.
  def reply_result
    return "call_booked" if call_booked
    return "interested" if positive_reply
    return "replied" if replied

    nil
  end

  private

  # Keep the flags consistent: a booked call is a positive reply, which is a reply, which means accepted.
  def normalize
    self.positive_reply = true if call_booked
    self.replied = true if positive_reply
    self.connection_accepted = true if replied || sent_at.present?
    self.replied_at ||= Time.current if replied
    self.replied_at = nil unless replied
    self.word_count = Drafting::MessageValidator.word_count(sent_body) if sent_body.present?
  end
end
