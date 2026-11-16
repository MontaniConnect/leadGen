# Builders for the staffing-firm partner track.
module PartnerTestHelper
  include OutreachTestHelper

  PARTNER_BODY = "Hi Dana, I noticed you place healthcare IT contractors. We're Montani, a Philippine-based team supporting " \
                 "long-term remote roles. Open to collaborating or overlapping on future client needs, however it might fit. " \
                 "Do you ever get requests you can't staff?".freeze

  def staffing_firm(name: "Talent Bridge", reasons: [ "excluded_keyword: staffing" ], **attrs)
    Company.create!({ name: name, domain: "#{name.downcase.delete(' ')}.com", website: "https://www.#{name.downcase.delete(' ')}.com",
                      country: "United States", employees: 60, industry: "Staffing & Recruiting", prefilter_status: "fail",
                      prefilter_reasons: reasons }.merge(attrs))
  end

  def partner_reply(body = PARTNER_BODY, **options)
    reply({ "observation" => "places healthcare IT contractors, Apollo", "body" => body }, **options)
  end
end
