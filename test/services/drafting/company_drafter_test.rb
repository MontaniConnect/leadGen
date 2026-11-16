require "test_helper"

class Drafting::CompanyDrafterTest < ActiveSupport::TestCase
  include DraftingTestHelper

  setup { @company = hot_company }

  def drafter(gateway, **options) = Drafting::CompanyDrafter.new(gateway: gateway, **options)
  def bad = reply(drafts(curious: "#{'word ' * 55}?"))

  test "drafts a Hot company with one call" do
    gateway = FakeGateway.new(replies: [ reply(drafts) ])
    run = drafter(gateway).call(@company)

    assert_equal "ok", run.status
    assert_equal 1, gateway.requests.size
    assert_equal 2, @company.messages.count
    assert_equal [ { fallbacks: false } ], gateway.options
  end

  test "skips a company that is not Hot, or already drafted, without any API call" do
    gateway = FakeGateway.new(replies: [ reply(drafts) ])
    warm = hot_company(name: "Warm", tier: "Warm")
    assert_nil drafter(gateway).call(warm)

    drafter(gateway).call(@company)
    assert_nil drafter(FakeGateway.new).call(@company)
    assert_equal 1, gateway.requests.size
  end

  test "force re-drafts" do
    drafter(FakeGateway.new(replies: [ reply(drafts) ])).call(@company)
    gateway = FakeGateway.new(replies: [ reply(drafts(founder_evidence: "quote")) ])
    drafter(gateway).call(@company, force: true)

    assert_equal 3, @company.messages.count
    assert_equal 2, @company.draft_runs.count
  end

  test "a failed validation is retried once and every attempt is logged" do
    gateway = FakeGateway.new(replies: [ bad, reply(drafts) ])
    run = drafter(gateway).call(@company)

    assert_equal "ok", run.status
    assert_equal %w[failed ok], @company.draft_runs.order(:id).pluck(:status)
    assert_equal 2, gateway.requests.size
  end

  test "after the last attempt the failure is kept and no messages exist" do
    run = drafter(FakeGateway.new(replies: [ bad, bad ])).call(@company)

    assert_equal "failed", run.status
    assert_equal 0, @company.messages.count
    assert_includes Company.awaiting_drafts, @company
  end

  test "an API error is recorded and retried like any failed attempt" do
    error = Anthropic::Errors::APIConnectionError.new(url: URI("https://api.anthropic.com"), message: "boom")
    run = drafter(FakeGateway.new(replies: [ error, reply(drafts) ])).call(@company)

    assert_equal "ok", run.status
    assert_includes @company.draft_runs.order(:id).first.error, "APIConnectionError"
  end

  test "server-side fallback is passed through only when enabled" do
    gateway = FakeGateway.new(replies: [ reply(drafts) ])
    drafter(gateway, fallbacks: true).call(@company)
    assert_equal [ { fallbacks: true } ], gateway.options
  end

  test "awaiting_drafts uses the latest ok evaluation only" do
    assert_includes Company.awaiting_drafts, @company
    add_evaluation(@company, tier: "Cold")
    assert_not_includes Company.awaiting_drafts, @company
    add_evaluation(@company, tier: "Hot")
    assert_includes Company.awaiting_drafts, @company
    add_evaluation(@company, tier: "Cold", status: "failed")
    assert_includes Company.awaiting_drafts, @company, "a failed evaluation must not change the current tier"
  end

  test "the beta fallback request serializes with the beta flag and fallbacks" do
    request = Drafting::RequestBuilder.new.call(@company)
    body = Anthropic::Beta::MessageCreateParams.dump_request(
      request.merge(betas: [ Scoring::AnthropicGateway::FALLBACK_BETA ], fallbacks: :default)
    ).first
    assert_equal :default, body[:fallbacks]
    assert_equal "json_schema", body[:output_config][:format][:type]
  end
end
