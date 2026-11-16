# Builders for outreach tests: sends with known outcomes, so results can be checked by hand.
module OutreachTestHelper
  include LeadsTestHelper

  # One send with explicit outcome flags and snapshot, on a fresh company.
  def make_send(variant: "curious_question", tier: "Hot", size: 30, industry: "Software", title: "CEO", staffing: 8,
                automation: 6, replied: false, positive: false, booked: false, assignment: "random", messaged: true,
                accepted: false, **extra)
    company = Company.create!(name: "Co #{SecureRandom.hex(5)}", prefilter_status: "pass", employees: size, industry: industry)
    OutreachSend.create!(
      company: company, variant: variant, assignment: assignment, connection_sent_at: 3.days.ago,
      sent_at: (2.days.ago if messaged), sent_body: (messaged ? "Hi there, a short note?" : nil), tier: tier,
      staffing_score: staffing, automation_score: automation, employee_count: size, industry: industry,
      contact_title: title, replied: replied, positive_reply: positive, call_booked: booked,
      connection_accepted: accepted, **extra
    )
  end

  # `count` sends of the same kind; the first `replied` replied, the first `positive` of those were positive,
  # and the first `booked` of those booked a call.
  def make_sends(count, replied: 0, positive: 0, booked: 0, **attrs)
    Array.new(count) do |i|
      make_send(replied: i < replied, positive: i < positive, booked: i < booked, **attrs)
    end
  end
end
