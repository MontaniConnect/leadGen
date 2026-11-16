module DashboardHelper
  def contact_label(company)
    return "" unless company.prefilter_status == "pass"
    return "Not found" unless company.selected_contact

    contact = company.selected_contact
    [ contact.full_name, contact.title ].compact_blank.join(", ")
  end

  # The "Why" column header: a link that toggles the sort between A to Z and Z to A.
  def why_header(sort_dir, filters)
    next_dir = sort_dir == "asc" ? "desc" : "asc"
    arrow = { "asc" => " ↑", "desc" => " ↓" }.fetch(sort_dir.to_s, "")
    link_to "Why#{arrow}", dashboard_path(filters.merge(sort: "why", dir: next_dir)),
            title: "Sort by why, #{next_dir == 'asc' ? 'A to Z' : 'Z to A'}"
  end

  def aria_sort(sort_dir) = { "asc" => "ascending", "desc" => "descending" }[sort_dir.to_s] || "none"

  def money(amount) = amount < 1 ? format("$%.4f", amount) : format("$%.2f", amount)

  # "Warm 6/6, High" for a scored company, blank otherwise.
  def scored_label(company)
    evaluation = company.current_evaluation
    return "" unless evaluation

    "#{evaluation.tier} #{evaluation.staffing_score}/#{evaluation.automation_score}, #{evaluation.confidence}"
  end

  # Label and confirmation text for a paid step button, showing what it could cost.
  def paid_button(verb, readiness, noun)
    cost = "about #{money(readiness.expected_cost)}, at most #{money(readiness.worst_case_cost)}"
    {
      label: "#{verb} #{pluralize(readiness.count, noun)} (#{cost})",
      confirm: "#{verb} #{pluralize(readiness.count, noun)}? This calls the Anthropic API: expected #{money(readiness.expected_cost)}, " \
               "never more than #{money(readiness.worst_case_cost)}, and it stops by itself at your spending cap."
    }
  end
end
