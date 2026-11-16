require "test_helper"

class Outreach::HelpersTest < ActiveSupport::TestCase
  include OutreachTestHelper

  test "signal tags: where each signal came from, plus offshore openness and regulated data" do
    company = lead(name: "Acme")
    company.pages.create!(kind: "careers", url: "https://acme.com/careers", status: "ok")
    evaluation = company.current_evaluation
    assert_equal %w[careers apollo regulated_data], Outreach::SignalTags.call(company.reload, evaluation)

    evaluation.update!(offshore_signal: "Mentions a Manila office", red_flags: [])
    assert_equal %w[careers apollo offshore_openness], Outreach::SignalTags.call(company.reload, evaluation)

    evaluation.update!(signals: [ { "signal" => "x", "source" => "https://elsewhere.com/y" } ], offshore_signal: "Not found")
    assert_equal [ "other" ], Outreach::SignalTags.call(company.reload, evaluation)
  end

  test "the snapshot freezes the lead as it was at send time" do
    company = lead(name: "Acme")
    company.update!(industry: "Software", employees: 42)
    snapshot = Outreach::Snapshot.call(company.reload)

    assert_equal [ "Hot", 8, 6, "Medium", "Software", 42, "CEO", true ],
                 snapshot.values_at(:tier, :staffing_score, :automation_score, :confidence, :industry, :employee_count, :contact_title, :had_why_now)
    assert_equal({}, Outreach::Snapshot.call(Company.create!(name: "Unscored")))
  end

  test "why-now counts only when the model found something" do
    company = lead(name: "Acme")
    company.current_evaluation.update!(why_now: "Not found")
    assert_equal false, Outreach::Snapshot.call(company.reload)[:had_why_now]
  end

  test "segments: size bands, score bands, and title buckets from the title tiers" do
    segments = Outreach::Segments.new
    record = Struct.new(:tier, :staffing_score, :automation_score, :industry, :employee_count, :contact_title)

    assert_equal [ "10-24", "25-49", "50-99", "50-99", "100-200", "Outside range", "Unknown" ],
                 [ 10, 49, 99, 75, 200, 500, nil ].map { |count| segments.size_band(count) }
    assert_equal [ "9-10", "7-8", "5-6", "1-4" ], [ [ 10, 2 ], [ 3, 7 ], [ 5, 5 ], [ 4, 1 ] ].map { |s, a| segments.score_band(record.new("Hot", s, a)) }

    assert_equal "CEO / Founder", segments.title_bucket("Founder & CEO")
    assert_equal "CTO", segments.title_bucket("CTO")
    assert_equal "Head of Engineering / Operations", segments.title_bucket("Head of Operations")
    assert_equal "Other senior", segments.title_bucket("Director of Marketing")
    assert_equal "Other", segments.title_bucket("Sales Rep")
    assert_equal "Unknown", segments.title_bucket(nil)
    assert_equal "Other", segments.title_bucket("Assistant to the CEO"), "excluded titles never count as leaders"

    row = segments.for(record.new("Warm", 4, 6, "Logistics", 60, "CTO"))
    assert_equal({ "tier" => "Warm", "title" => "CTO", "size" => "50-99", "industry" => "Logistics", "score" => "5-6" }, row)
  end

  test "approvals: the most specific approved segment wins, and removals stick" do
    approvals = Outreach::Approvals.new
    segments = { "tier" => "Hot", "title" => "CEO / Founder", "size" => "25-49", "industry" => "Software", "score" => "9-10" }
    assert_nil approvals.default_for(segments)

    approvals.approve_default!("tier", "Hot", "curious_question")
    assert_equal "curious_question", approvals.default_for(segments)
    approvals.approve_default!("title", "CEO / Founder", "founder_time")
    assert_equal "founder_time", approvals.default_for(segments), "title is more specific than tier"

    approvals.revoke_default!("title:CEO / Founder")
    assert_equal "curious_question", approvals.default_for(segments)

    approvals.approve_example!(7)
    approvals.approve_example!("7")
    assert_equal [ 7 ], approvals.example_ids
    approvals.revoke_example!(7)
    assert_empty approvals.example_ids
  end

  test "the anonymizer swaps the recipient's name and the company name for placeholders" do
    company = Company.create!(name: "Acme Robotics")
    contact = company.contacts.create!(first_name: "Ada", title: "CEO")
    record = OutreachSend.new(company: company, contact: contact, sent_body: "Hi Ada, how is Acme Robotics handling support? Ada, any thoughts?")
    assert_equal "Hi <first name>, how is <company> handling support? <first name>, any thoughts?", Outreach::Anonymizer.call(record)

    no_contact = OutreachSend.new(company: company, sent_body: "Hello Sam, quick one?")
    assert_equal "Hello <first name>, quick one?", Outreach::Anonymizer.call(no_contact)
  end
end
