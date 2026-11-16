require "test_helper"

class Outreach::DraftingExamplesTest < ActiveSupport::TestCase
  include OutreachTestHelper

  def approve(send_record) = Outreach::Approvals.new.approve_example!(send_record.id)

  test "only approved messages that earned a positive reply are ever returned" do
    approved = make_send(replied: true, positive: true, sent_body: "Hi Ada, approved one?")
    unapproved = make_send(replied: true, positive: true, sent_body: "Hi Sam, not approved?")
    negative = make_send(replied: true, sent_body: "Hi Lee, replied but negative?")
    approve(approved)
    approve(negative)

    texts = Outreach::ApprovedExamples.call
    assert_equal [ "Hi <first name>, approved one?" ], texts
    assert_not_includes texts.join, unapproved.sent_body
  end

  test "the number of examples is capped" do
    5.times { |i| approve(make_send(replied: true, positive: true, sent_body: "Hi A#{i}, note #{i}?")) }
    assert_equal 3, Outreach::ApprovedExamples.call.size
    assert_equal 2, Outreach::ApprovedExamples.call(max: 2).size
  end

  test "with no approved examples the drafting prompt is exactly what it was before" do
    builder = Drafting::RequestBuilder.new
    assert_equal Drafting::Prompt::SYSTEM.sub("{TARGET_WORDS}", "45"), builder.system_text
    assert_equal "v1", builder.prompt_version
  end

  test "approved examples are added to the cached instructions, anonymised, and change the prompt version" do
    approve(make_send(replied: true, positive: true, sent_body: "Hi Ada, how do you split support work?"))
    builder = Drafting::RequestBuilder.new
    request = builder.call(hot_company(name: "Acme"))

    text = request[:system_].first[:text]
    assert_includes text, "MESSAGES THAT EARNED POSITIVE REPLIES"
    assert_includes text, "\"Hi <first name>, how do you split support work?\""
    assert_includes text, "write fresh wording, and use only facts from the lead"
    assert_match(/\Av1\+ex[0-9a-f]{6}\z/, builder.prompt_version)
    assert_equal({ type: "ephemeral", ttl: "1h" }, request[:system_].first[:cache_control])
  end

  test "the same examples always give the same prompt, so the cache stays valid" do
    approve(make_send(replied: true, positive: true, sent_body: "Hi Ada, one?"))
    assert_equal Drafting::RequestBuilder.new.system_text, Drafting::RequestBuilder.new.system_text
  end

  test "drafts record the prompt version they were generated with, examples included" do
    approve(make_send(replied: true, positive: true, sent_body: "Hi Ada, one?"))
    company = hot_company(name: "Hot")
    drafter = Drafting::CompanyDrafter.new(gateway: FakeGateway.new(replies: [ reply(drafts) ]))
    run = drafter.call(company)

    assert_match(/\Av1\+ex/, run.prompt_version)
    assert_equal run.prompt_version, company.messages.first.prompt_version
  end

  test "the dry run prices the examples because they are part of the instructions" do
    plain = Budget::DryRun.new
    base = plain.instance_variable_get(:@drafting_builder).system_text.length
    approve(make_send(replied: true, positive: true, sent_body: "Hi Ada, one?"))
    assert_operator Drafting::RequestBuilder.new.system_text.length, :>, base
  end
end
