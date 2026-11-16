module Pilot
  # Step 4 of the pilot: one line per pilot company so the results can be judged by eye.
  class Report
    def initialize(out: $stdout)
      @out = out
    end

    def call
      @out.puts format("%-26s %-5s %-24s %-4s %-9s %-7s %-6s %s", "Company", "Pre", "Contact", "Pgs", "Tier", "S/A", "Drafts", "Cost")
      Pilot.scope.includes(:pages, :evaluations, :messages, :draft_runs, :selected_contact).order(:name).each { |company| @out.puts line(company) }
    end

    private

    def line(company)
      evaluation = company.current_evaluation
      cost = company.evaluations.sum(&:cost_usd) + company.draft_runs.sum(&:cost_usd)
      format("%-26s %-5s %-24s %-4s %-9s %-7s %-6s %s", company.name.truncate(26), company.prefilter_status,
             company.selected_contact&.full_name.to_s.truncate(24), company.pages.count { |page| page.status == "ok" },
             evaluation ? "#{evaluation.tier}/#{evaluation.confidence[0]}" : "-",
             evaluation ? "#{evaluation.staffing_score}/#{evaluation.automation_score}" : "-",
             company.messages.size, format("$%.4f", cost))
    end
  end
end
