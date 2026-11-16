require "test_helper"

class Drafting::RecorderTest < ActiveSupport::TestCase
  include DraftingTestHelper

  setup { @company = hot_company }

  def record(data, **reply_options) = Drafting::Recorder.new.call(@company, reply(data, **reply_options))
  def labels = @company.messages.order(:id).pluck(:label)

  test "stores three drafts when the founder angle has evidence" do
    run = record(drafts(founder_evidence: "CEO answers tickets: https://acme.com/about"))

    assert_equal "ok", run.status
    assert_equal %w[curious_question founder_time low_pressure_offer], labels.sort
    message = @company.messages.find_by!(label: "curious_question")
    assert_equal "draft", message.status
    assert_equal @company.selected_contact, message.contact
    assert_equal run, message.draft_run
    assert_equal "claude-sonnet-5-5", message.model
    assert_equal "v2", message.prompt_version
    assert_operator message.word_count, :<=, 50
    assert_includes message.evidence, "support split"
    assert_equal [ 900, 150, 700 ], [ run.tokens_in, run.tokens_out, run.cache_read_tokens ]
  end

  test "without evidence the founder variant is dropped even if the model wrote one" do
    record(drafts(founder_evidence: "Not found"))
    assert_equal %w[curious_question low_pressure_offer], labels
  end

  test "evidence check is case-insensitive and ignores blanks" do
    record(drafts(founder_evidence: " NOT FOUND "))
    assert_equal 2, labels.size
    @company.messages.destroy_all
    record(drafts(founder_evidence: ""))
    assert_equal 2, labels.size
  end

  test "a founder variant that fails validation is dropped, not fatal" do
    long = "word " * 60
    run = record(drafts(founder_evidence: "quote", founder: "#{long}?"))
    assert_equal "ok", run.status
    assert_equal %w[curious_question low_pressure_offer], labels
  end

  test "a required variant over 50 words fails the run and stores no messages" do
    run = record(drafts(curious: "#{'word ' * 55}?"))

    assert_equal "failed", run.status
    assert_includes run.error, "curious_question: over_word_limit (56 > 50)"
    assert_equal 0, @company.messages.count
    assert_equal 900, run.tokens_in
  end

  test "a missing required variant, a duplicate label, bad JSON and a refusal all fail" do
    only_curious = drafts.tap { |d| d["variants"].reject! { |v| v["label"] == "low_pressure_offer" } }
    assert_includes record(only_curious).error, "low_pressure_offer: missing"

    duplicate = drafts.tap { |d| d["variants"] << d["variants"].first.dup }
    duplicate["variants"] = duplicate["variants"].first(3)
    duplicate["variants"][1] = duplicate["variants"][0].dup
    assert_includes record(duplicate).error, "duplicate variant"

    assert_includes record("nope").error, "invalid JSON"
    assert_includes record("", stop_reason: "refusal", refusal_category: "general_harms").error, "refusal (general_harms)"
    assert_equal 0, @company.messages.count
  end

  test "regenerating replaces unedited drafts but never touches edited or sent messages" do
    record(drafts)
    @company.messages.find_by!(label: "curious_question").update!(status: "sent")
    @company.messages.find_by!(label: "low_pressure_offer").update!(status: "edited", body: "Hi Ada, my own words?")

    record(drafts)

    assert_equal [ "edited", "sent" ], @company.messages.where.not(status: "draft").order(:status).pluck(:status)
    assert_equal 2 + 2, @company.messages.count # 2 kept + 2 fresh drafts (no founder evidence)
  end
end
