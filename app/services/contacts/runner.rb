module Contacts
  # Records the chosen contact on every prefilter-passed company and every partner candidate, or flags "not_found".
  # Re-running after new contacts arrive (Apollo import, site fallback) updates the choice.
  class Runner
    def initialize(selector: Selector.new, scope: Company.prefilter_passed.or(Company.partner_candidates))
      @selector = selector
      @scope = scope
    end

    def call
      tally = Hash.new(0)
      @scope.includes(:contacts).find_each do |company|
        contact = @selector.call(company)
        status = contact ? "selected" : "not_found"
        company.update!(selected_contact: contact, contact_status: status)
        tally[status] += 1
      end
      tally
    end
  end
end
