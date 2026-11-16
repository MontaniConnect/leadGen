# Builds scored, drafted leads for review-screen tests.
module LeadsTestHelper
  include DraftingTestHelper

  def lead(name: "Acme", tier: "Hot", staffing: 8, automation: 6, drafted: true, **company_attrs)
    company = Company.create!({ name: name, domain: "#{name.downcase}.com", website: "https://www.#{name.downcase}.com",
                                prefilter_status: "pass" }.merge(company_attrs))
    company.contacts.create!(first_name: "Ada", last_name: "Lovelace", title: "CEO",
                             linkedin_url: "https://www.linkedin.com/in/ada")
    company.update!(selected_contact: company.contacts.first, contact_status: "selected")
    company.evaluations.create!(
      status: "ok", tier: tier, staffing_score: staffing, automation_score: automation, confidence: "Medium",
      signals: [ { "signal" => "Hiring a Salesforce admin", "source" => "https://#{name.downcase}.com/careers" },
                 { "signal" => "Mid-size team", "source" => "Apollo: # Employees" } ],
      red_flags: [ { "flag" => "Handles patient data", "source" => "https://#{name.downcase}.com/about" } ],
      offshore_signal: "Not found", why_now: "Raised Series A in October", why_now_source: "Apollo: Last Raised At",
      lead_with: "Salesforce specialists"
    )
    draft(company) if drafted
    company
  end

  def draft(company)
    run = company.draft_runs.create!(status: "ok")
    { "curious_question" => CURIOUS, "founder_time" => FOUNDER, "low_pressure_offer" => OFFER }.each do |label, body|
      company.messages.create!(label: label, body: body, draft_run: run, contact: company.selected_contact)
    end
  end
end
