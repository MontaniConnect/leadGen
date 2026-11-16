class Company < ApplicationRecord
  belongs_to :import_batch, optional: true
  belongs_to :selected_contact, class_name: "Contact", optional: true
  has_many :contacts, dependent: :destroy
  has_many :pages, dependent: :destroy
  has_many :evaluations, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :draft_runs, dependent: :destroy
  has_one :outreach_send, dependent: :destroy

  REPLY_RESULTS = {
    "replied" => "Replied", "interested" => "Interested", "call_booked" => "Call booked",
    "no_reply" => "No reply", "not_a_fit" => "Not a fit"
  }.freeze

  scope :prefilter_passed, -> { where(prefilter_status: "pass") }
  # Pass companies with no usable contact: the queue for the Phase 4 about-page fallback.
  scope :needing_site_contact, -> { prefilter_passed.where(contact_status: "not_found") }

  # Passed the prefilter and fetched at least once, with no successful evaluation yet.
  # A failed evaluation leaves a company here, so a plain re-run retries it.
  scope :awaiting_evaluation, lambda {
    prefilter_passed.where(id: Page.select(:company_id))
                    .where.not(id: Evaluation.where(status: "ok").select(:company_id))
  }

  # The company's latest successful evaluation is in one of these tiers.
  scope :in_tiers, ->(tiers) { where(id: Evaluation.current.where(tier: tiers).select(:company_id)) }
  scope :hot, -> { in_tiers("Hot") }
  # Leads that get messages drafted: the tiers in drafting.tiers (Hot and Warm by default).
  scope :draftable, -> { in_tiers(Setting.get("drafting.tiers")) }
  scope :awaiting_drafts, -> { draftable.where.not(id: DraftRun.where(status: "ok").select(:company_id)) }

  before_save { self.name_key = Imports::NameKey.call(name) if name_changed? || name_key.blank? }

  # Staffing, recruiting and outsourcing firms: the ones the filter excluded for that reason, and the ones the
  # scorer flagged as competitors. They are not sales leads; they get a partnership message instead.
  scope :partner_candidates, lambda {
    excluded = where(prefilter_status: "fail").where("prefilter_reasons::text LIKE ?", "%excluded_%")
    competitor = where(id: Evaluation.current.where(disqualified: true).select(:company_id))
    excluded.or(competitor).where(partner_dismissed_at: nil)
  }
  # Removed from the Partners list by a person ("not a staffing firm"); can be restored.
  scope :partner_dismissed, -> { where.not(partner_dismissed_at: nil) }
  scope :awaiting_partner_drafts, -> { partner_candidates.where.not(id: Message.where(label: "partnership").select(:company_id)) }

  validates :name, presence: true
  validates :apollo_account_id, uniqueness: true, allow_nil: true
  validates :reply_result, inclusion: { in: REPLY_RESULTS.keys }, allow_nil: true

  # Uses the loaded association when present, so list views can preload evaluations.
  def current_evaluation
    return evaluations.ok.order(:id).last unless evaluations.loaded?

    evaluations.select { |evaluation| evaluation.status == "ok" }.max_by(&:id)
  end

  def lead_status
    return REPLY_RESULTS.fetch(reply_result) if reply_result.present?

    return "Message sent" if outreach_send&.sent_at

    connection_sent_at ? "Connection sent" : "To contact"
  end
end
