# Fakes and builders for scoring tests: no network, no SDK.
module ScoringTestHelper
  VALID_OUTPUT = {
    "staffing_score" => 8, "automation_score" => 6,
    "top_signals" => [ { "signal" => "Hiring AWS engineers", "source" => "https://acme.com/careers" } ],
    "red_flags" => [], "offshore_signal" => "Not found", "why_now" => "Raised Series A",
    "why_now_source" => "Apollo: Last Raised At", "lead_with" => "AWS engineers on US hours", "disqualified" => false
  }.freeze

  def reply(output = VALID_OUTPUT, stop_reason: "end_turn", **overrides)
    text = output.is_a?(String) ? output : output.to_json
    Scoring::Reply.new(**{ text: text, stop_reason: stop_reason, refusal_category: nil, input_tokens: 900,
                           output_tokens: 150, cache_read_tokens: 700, cache_write_tokens: 0 }.merge(overrides))
  end

  def company_with_pages(name: "Acme", kinds: %w[home about careers])
    company = Company.create!(name: name, domain: "#{name.downcase}.com", prefilter_status: "pass",
                              short_description: "B2B logistics software")
    kinds.each do |kind|
      company.pages.create!(kind: kind, url: "https://#{company.domain}/#{kind}", status: "ok",
                            text: "#{kind} page text", fetched_at: Time.current)
    end
    company
  end

  # Records calls and returns canned replies.
  class FakeGateway
    attr_reader :requests, :batches, :options

    def initialize(replies: [], batch_status: nil, batch_entries: [])
      @replies = replies
      @requests = []
      @options = []
      @batches = []
      @batch_status = batch_status
      @batch_entries = batch_entries
    end

    def message(request, **options)
      @requests << request
      @options << options
      reply = @replies.shift
      raise reply if reply.is_a?(Exception)

      reply
    end

    def create_batch(entries)
      @batches << entries
      "msgbatch_#{@batches.size}"
    end

    def count_tokens(request)
      (@token_counts ||= []) << request[:model]
      @token_count_value || 4000
    end

    attr_reader :token_counts
    attr_writer :token_count_value

    def batch_status(_id) = @batch_status
    def batch_results(_id, &block) = @batch_entries.each(&block)
  end
end
