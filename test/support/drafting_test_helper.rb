# Builders for drafting tests. Reuses ScoringTestHelper's FakeGateway and reply().
module DraftingTestHelper
  include ScoringTestHelper

  CURIOUS = "Hi Ada, I'm curious how you split support between your US team and your platform team. " \
            "We place Philippine-based support agents and developers on US hours. Happy to help however it fits. " \
            "Is anything stretched right now?".freeze
  FOUNDER = "Hi Ada, I noticed you still answer customers directly. We place Philippine-based support agents " \
            "on US hours, happy to help whenever it fits. Would some of that time back be useful?".freeze
  OFFER = "Hi Ada, your careers page lists a Salesforce admin role. We place Philippine-based Salesforce " \
          "specialists on US hours, and we're happy to help whenever timing fits. Is hiring that role on your plate?".freeze

  def drafts(founder_evidence: "Not found", curious: CURIOUS, founder: FOUNDER, offer: OFFER, include_founder: true)
    variants = [
      { "label" => "curious_question", "observation" => "support split, https://acme.com/about", "body" => curious },
      { "label" => "low_pressure_offer", "observation" => "Salesforce role, https://acme.com/careers", "body" => offer }
    ]
    variants.insert(1, { "label" => "founder_time", "observation" => "CEO answers tickets", "body" => founder }) if include_founder
    { "founder_time_evidence" => founder_evidence, "variants" => variants }
  end

  def hot_company(name: "Acme", tier: "Hot")
    company = company_with_pages(name: name)
    company.contacts.create!(first_name: "Ada", last_name: "Lovelace", title: "CEO", linkedin_url: "https://linkedin.com/in/ada")
    company.update!(contact_status: "selected", selected_contact: company.contacts.first)
    add_evaluation(company, tier: tier)
    company
  end

  def add_evaluation(company, tier:, status: "ok")
    company.evaluations.create!(
      status: status, tier: tier, staffing_score: 8, automation_score: 6, confidence: "Medium",
      signals: [ { "signal" => "Hiring a Salesforce admin", "source" => "https://acme.com/careers" } ],
      red_flags: [ { "flag" => "Handles patient data", "source" => "https://acme.com/about" } ],
      offshore_signal: "Not found", why_now: "Raised Series A", why_now_source: "Apollo: Last Raised At",
      lead_with: "Salesforce specialists"
    )
  end
end
