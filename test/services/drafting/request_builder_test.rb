require "test_helper"

class Drafting::RequestBuilderTest < ActiveSupport::TestCase
  include DraftingTestHelper

  setup do
    @company = hot_company
    @request = Drafting::RequestBuilder.new.call(@company)
    @content = @request[:messages].first[:content]
  end

  test "uses the drafting model with medium effort, a token cap and no sampling params" do
    assert_equal "claude-sonnet-5-5", @request[:model]
    assert_equal 2000, @request[:max_tokens]
    assert_equal "medium", @request[:output_config][:effort]
    assert_empty @request.keys & %i[temperature top_p top_k tool_choice]
  end

  test "static instructions are cached, carry the word target, and hold no company data" do
    block = @request[:system_].first
    assert_equal({ type: "ephemeral", ttl: "1h" }, block[:cache_control])
    assert_includes block[:text], "at most 45 words"
    assert_not_includes block[:text], "{TARGET_WORDS}"
    assert_not_includes block[:text], "Acme"
  end

  test "lead block has the contact, findings with sources and page text" do
    assert_includes @content, "Contact first name: Ada"
    assert_includes @content, "Contact title: CEO"
    assert_includes @content, "Hiring a Salesforce admin (source: https://acme.com/careers)"
    assert_includes @content, "Handles patient data"
    assert_includes @content, 'source="https://acme.com/about"'
  end

  test "no selected contact is passed as none" do
    @company.update!(selected_contact: nil)
    assert_includes Drafting::EvidenceFormatter.new.call(@company.reload), "Contact first name: none"
  end

  test "page text is cut to the word budget" do
    @company.pages.find_by!(kind: "home").update!(text: (1..100).to_a.join(" "))
    content = Drafting::EvidenceFormatter.new(page_words: 3).call(@company.reload)
    assert_includes content, "1 2 3\n</page>"
  end
end
