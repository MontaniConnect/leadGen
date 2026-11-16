require "test_helper"

class Scoring::RequestBuilderTest < ActiveSupport::TestCase
  include ScoringTestHelper

  setup do
    @company = company_with_pages
    @company.update!(employees: 40, country: "United States", technologies: "AWS", last_raised_at: Date.new(2026, 10, 1))
    @request = Scoring::RequestBuilder.new(formatter: Scoring::EvidenceFormatter.new(today: Date.new(2026, 11, 16))).call(@company)
  end

  test "uses the configured scoring model, token cap and low effort" do
    assert_equal "claude-haiku-5-5", @request[:model]
    assert_equal 3000, @request[:max_tokens]
    assert_equal "low", @request[:output_config][:effort]
    assert_equal "json_schema", @request[:output_config][:format_][:type]
  end

  test "static instructions are cached and contain no per-company data" do
    block = @request[:system_].first
    assert_equal({ type: "ephemeral", ttl: "1h" }, block[:cache_control])
    assert_equal Scoring::Prompt::SYSTEM, block[:text]
    assert_not_includes block[:text], "Acme"
  end

  test "no sampling parameters are sent" do
    assert_empty @request.keys & %i[temperature top_p top_k]
  end

  test "per-company evidence carries labeled sources and today's date" do
    content = @request[:messages].first[:content]
    assert_includes content, "Today's date: 2026-11-16"
    assert_includes content, "Technologies: AWS"
    assert_includes content, "Last Raised At: 2026-10-01"
    assert_includes content, 'source="https://acme.com/careers"'
    assert_includes content, "<company_data>"
  end

  test "failed pages and blank apollo fields are left out" do
    @company.pages.find_by!(kind: "about").update!(status: "not_found", text: nil)
    content = Scoring::EvidenceFormatter.new.call(@company.reload)
    assert_not_includes content, "/about"
    assert_not_includes content, "Annual Revenue"
  end

  test "pages are cut to the word budget" do
    @company.pages.find_by!(kind: "home").update!(text: (1..50).to_a.join(" "))
    content = Scoring::EvidenceFormatter.new(words_per_page: 5).call(@company.reload)
    assert_includes content, "1 2 3 4 5\n</page>"
  end
end
