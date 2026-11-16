module Contacts
  # Looks for a decision-maker on a company's own website: re-reads its About page and picks out a clearly
  # labelled leader (CEO, founder, CTO, head of engineering or operations). Free: it only makes polite
  # requests to the company's site. It never reads LinkedIn. The result is remembered on the company so the
  # screen can say "checked, nothing clear found" instead of leaving a blank.
  class WebsiteResearch
    Outcome = Data.define(:status, :contact) # :found, :already_has_contact, :no_clear_name, :site_unreachable, :no_website

    def initialize(fetcher: Fetching::CompanyFetcher.new)
      @fetcher = fetcher
    end

    def call(company)
      return Outcome.new(:no_website, nil) if company.domain.blank?
      return Outcome.new(:already_has_contact, company.selected_contact) if company.contact_status == "selected"

      @fetcher.call(company, force: %w[about], kinds: %w[about])
      Runner.new(scope: Company.where(id: company.id)).call
      company.reload
      outcome = outcome_for(company)
      company.update!(contact_researched_at: Time.current, contact_research_result: outcome.status.to_s)
      outcome
    end

    private

    def outcome_for(company)
      return Outcome.new(:found, company.selected_contact) if company.selected_contact

      about = company.pages.find_by(kind: "about")
      Outcome.new(about&.status == "ok" ? :no_clear_name : :site_unreachable, nil)
    end
  end
end
