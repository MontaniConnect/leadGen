require "test_helper"

# Builds real SDK objects (no network) to prove the gateway reads them correctly.
class Scoring::AnthropicGatewayTest < ActiveSupport::TestCase
  def sdk_message(text: "{}", stop_reason: :end_turn, stop_details: {})
    Anthropic::Models::Message.new(
      id: "msg_1", type: :message, role: :assistant, model: "claude-haiku-5-5", stop_reason: stop_reason,
      stop_sequence: nil, **stop_details,
      content: [ { type: :text, text: text, citations: nil } ],
      usage: { input_tokens: 900, output_tokens: 150, cache_read_input_tokens: 700, cache_creation_input_tokens: 5 }
    )
  end

  test "converts an SDK message to a Reply" do
    gateway = Scoring::AnthropicGateway.new(Object.new)
    reply = gateway.send(:reply_from, sdk_message(text: '{"a":1}'))

    assert_equal '{"a":1}', reply.text
    assert_equal "end_turn", reply.stop_reason
    assert_equal [ 900, 150, 700, 5 ], [ reply.input_tokens, reply.output_tokens, reply.cache_read_tokens, reply.cache_write_tokens ]
  end

  test "reads a refusal category from stop_details" do
    message = sdk_message(stop_reason: :refusal, stop_details: { stop_details: { type: :refusal, category: :cyber } })
    reply = Scoring::AnthropicGateway.new(Object.new).send(:reply_from, message)

    assert_equal "refusal", reply.stop_reason
    assert_equal "cyber", reply.refusal_category
  end

  test "from_environment refuses to run without a key" do
    credentials = Struct.new(:key) { def dig(*) = key }.new(nil)
    assert_raises(Scoring::AnthropicGateway::MissingApiKey) do
      Scoring::AnthropicGateway.from_environment(env: {}, credentials: credentials)
    end
  end

  test "from_environment builds a gateway from the ENV key" do
    assert_instance_of Scoring::AnthropicGateway,
                       Scoring::AnthropicGateway.from_environment(env: { "ANTHROPIC_API_KEY" => "sk-test" })
  end
end
