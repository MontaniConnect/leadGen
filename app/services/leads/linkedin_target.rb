module Leads
  # Where the "open LinkedIn" button points, in fixed order of preference:
  # the contact's profile, then the company's LinkedIn page, then nothing.
  class LinkedinTarget
    PROFILE_LABEL = "Open LinkedIn profile".freeze
    COMPANY_LABEL = "Company page (no contact found)".freeze
    NONE_LABEL = "No LinkedIn link".freeze

    def self.call(company)
      profile = web_url(company.selected_contact&.linkedin_url)
      return Target.new(:profile, profile, PROFILE_LABEL) if profile

      page = web_url(company.linkedin_url)
      return Target.new(:company_page, page, COMPANY_LABEL) if page

      Target.new(:none, nil, NONE_LABEL)
    end

    # Only plain http(s) URLs are ever linked (never javascript: or data:).
    def self.web_url(value)
      url = value.to_s.strip
      url if url.match?(%r{\Ahttps?://[^\s]+\z}i)
    end
  end
end
