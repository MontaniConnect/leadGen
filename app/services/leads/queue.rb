module Leads
  # The ordered set of leads shown in the review queue, and the exact set an export of that view contains.
  # A lead is a company whose latest successful evaluation matches the filters, best score first.
  class Queue
    TIERS = %w[Hot Warm].freeze
    ALL_TIERS = %w[Hot Warm Cold].freeze
    DEFAULT_TIER = "Hot".freeze
    STATUSES = %w[to_contact sent].freeze
    NO_REPLY = "none".freeze
    LIMIT = 300 # what the screen lists; exports are not capped

    attr_reader :tier, :status, :reply, :batch

    # all_tiers: every scored lead regardless of tier (the "export all" scope); tier is ignored then.
    def initialize(tier: nil, status: nil, reply: nil, batch: nil, all_tiers: false)
      @all_tiers = all_tiers
      @tier = TIERS.include?(tier) ? tier : DEFAULT_TIER
      @status = STATUSES.include?(status) ? status : nil
      @reply = (Company::REPLY_RESULTS.keys + [ NO_REPLY ]).include?(reply) ? reply : nil
      @batch = batch.to_s.match?(/\A\d+\z/) ? batch.to_i : nil
    end

    def to_contact? = status == "to_contact"

    # Filters as URL params, omitting unset ones.
    def filters
      { tier: tier, status: status, reply: reply, batch: batch }.compact.transform_values(&:to_s)
    end

    def scope
      relation = Company.joins(:evaluations).merge(Evaluation.current)
                        .where(evaluations: { tier: @all_tiers ? ALL_TIERS : tier })
      relation = apply_status(relation)
      relation = apply_reply(relation)
      relation = relation.where(import_batch_id: batch) if batch
      relation.order(Arel.sql("GREATEST(evaluations.staffing_score, evaluations.automation_score) DESC, companies.name ASC"))
    end

    def companies
      scope.preload(:evaluations, :selected_contact, :outreach_send).limit(LIMIT).to_a
    end

    def count = scope.count

    private

    def apply_status(relation)
      case status
      when "to_contact" then relation.where(connection_sent_at: nil, reply_result: nil)
      when "sent" then relation.where.not(connection_sent_at: nil)
      else relation
      end
    end

    def apply_reply(relation)
      return relation unless reply

      reply == NO_REPLY ? relation.where(reply_result: nil) : relation.where(reply_result: reply)
    end
  end
end
