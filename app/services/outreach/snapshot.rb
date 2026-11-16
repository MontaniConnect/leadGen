module Outreach
  # The lead as it was when the connection request went out. Scores and tier can change later when a
  # lead is re-scored, so results are always judged against what we knew at send time.
  module Snapshot
    def self.call(company)
      evaluation = company.current_evaluation
      return {} unless evaluation

      {
        tier: evaluation.tier, staffing_score: evaluation.staffing_score, automation_score: evaluation.automation_score,
        confidence: evaluation.confidence, industry: company.industry, employee_count: company.employees,
        contact_title: company.selected_contact&.title,
        had_why_now: SignalTags.present?(evaluation.why_now), signal_tags: SignalTags.call(company, evaluation)
      }
    end
  end
end
