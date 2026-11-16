require "test_helper"

class Pipeline::RedraftTest < ActiveSupport::TestCase
  include PartnerTestHelper

  def redraft(replies, **options)
    out = StringIO.new
    run = Pipeline::Redraft.new(gateway: FakeGateway.new(replies: replies), out: out, **options).call
    [ run, out.string ]
  end

  def age(company, version) = company.messages.update_all(prompt_version: version)

  test "leads and partners drafted with an older prompt are re-drafted with the current one, in one tracked run" do
    old_lead = hot_company(name: "Old Lead")
    Drafting::CompanyDrafter.new(gateway: FakeGateway.new(replies: [ reply(drafts) ])).call(old_lead)
    age(old_lead, "v1")
    firm = staffing_firm
    Partnering::Recorder.new.call(firm, partner_reply)
    age(firm, "p1")

    run, output = redraft([ reply(drafts), partner_reply ])

    assert_equal [ "draft", "complete" ], [ run.kind, run.status ]
    assert_includes output, "Old Lead: re-drafted"
    assert_includes output, "Talent Bridge: re-drafted"
    assert_equal [ "v2" ], old_lead.reload.messages.pluck(:prompt_version).uniq
    assert_equal [ "p2" ], firm.reload.messages.pluck(:prompt_version).uniq
    assert_equal 2, old_lead.messages.count, "replaced, not duplicated"
    assert_equal 1, firm.messages.count
  end

  test "already-current drafts are left alone, with no API call" do
    lead = hot_company(name: "Current")
    Drafting::CompanyDrafter.new(gateway: FakeGateway.new(replies: [ reply(drafts) ])).call(lead)
    gateway = FakeGateway.new
    Pipeline::Redraft.new(gateway: gateway, out: StringIO.new).call
    assert_empty gateway.requests
  end

  test "anything a person edited or marked sent is never replaced" do
    edited = hot_company(name: "Edited")
    Drafting::CompanyDrafter.new(gateway: FakeGateway.new(replies: [ reply(drafts) ])).call(edited)
    age(edited, "v1")
    edited.messages.first.update!(status: "edited", body: "Hi Ada, my own words?")

    gateway = FakeGateway.new
    Pipeline::Redraft.new(gateway: gateway, out: StringIO.new).call
    assert_empty gateway.requests
    assert_equal "Hi Ada, my own words?", edited.messages.find_by!(status: "edited").body
  end

  test "it stops at the spending cap and says so" do
    2.times { |i| lead = hot_company(name: "Lead #{i}"); Drafting::CompanyDrafter.new(gateway: FakeGateway.new(replies: [ reply(drafts) ])).call(lead); age(lead, "v1") }
    Setting.set("budget.spending_cap_usd", 0.0005)
    run, = redraft([ reply(drafts), reply(drafts) ])
    assert_equal "halted", run.status
    assert_match(/Spending cap reached/, run.halted_reason)
  end
end
