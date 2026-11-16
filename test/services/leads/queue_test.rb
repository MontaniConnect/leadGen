require "test_helper"

class Leads::QueueTest < ActiveSupport::TestCase
  include LeadsTestHelper

  test "lists the chosen tier, best score first, then name" do
    lead(name: "Low", staffing: 7, automation: 3)
    lead(name: "High", staffing: 4, automation: 9)
    lead(name: "Alpha", staffing: 7, automation: 3)
    lead(name: "WarmCo", tier: "Warm", staffing: 6, automation: 5)

    assert_equal %w[High Alpha Low], Leads::Queue.new(tier: "Hot").companies.map(&:name)
    assert_equal %w[WarmCo], Leads::Queue.new(tier: "Warm").companies.map(&:name)
  end

  test "an unknown tier falls back to Hot" do
    lead(name: "A")
    assert_equal "Hot", Leads::Queue.new(tier: "Cold; DROP TABLE").tier
  end

  test "uses only the latest ok evaluation of each company" do
    company = lead(name: "Changed")
    add_evaluation(company, tier: "Cold")
    add_evaluation(company, tier: "Hot", status: "failed")

    assert_empty Leads::Queue.new(tier: "Hot").companies
    assert_empty Leads::Queue.new(tier: "Warm").companies, "Cold is not a queue tier"
  end

  test "to_contact hides leads already sent or answered" do
    lead(name: "Fresh")
    lead(name: "Sent", connection_sent_at: Time.current)
    lead(name: "Answered", reply_result: "replied")

    assert_equal %w[Answered Fresh Sent], Leads::Queue.new.companies.map(&:name).sort
    assert_equal %w[Fresh], Leads::Queue.new(status: "to_contact").companies.map(&:name)
  end

  test "companies without a successful evaluation never appear" do
    Company.create!(name: "Unscored", prefilter_status: "pass")
    assert_empty Leads::Queue.new.companies
  end

  test "status, reply and import batch filters narrow the queue" do
    batch = ImportBatch.create!(kind: "accounts", filename: "a.csv")
    lead(name: "Fresh", import_batch: batch)
    lead(name: "Sent", connection_sent_at: Time.current)
    lead(name: "Replied", reply_result: "replied", connection_sent_at: Time.current)
    lead(name: "Other")

    names = ->(**f) { Leads::Queue.new(**f).companies.map(&:name).sort }
    assert_equal %w[Replied Sent], names.call(status: "sent")
    assert_equal %w[Replied], names.call(reply: "replied")
    assert_equal %w[Fresh Other Sent], names.call(reply: "none")
    assert_equal %w[Fresh], names.call(batch: batch.id.to_s)
    assert_equal %w[Fresh], names.call(batch: batch.id.to_s, status: "to_contact")
    assert_empty names.call(batch: batch.id.to_s, status: "sent")
  end

  test "unknown filter values are ignored, never passed to SQL" do
    queue = Leads::Queue.new(status: "x'; --", reply: "bogus", batch: "1 OR 1=1")
    assert_equal({ tier: "Hot" }, queue.filters.symbolize_keys)
  end

  test "all_tiers includes Cold and is not capped by the screen limit" do
    lead(name: "Hot1")
    lead(name: "Cold1", tier: "Cold", staffing: 2, automation: 2)
    assert_equal %w[Cold1 Hot1], Leads::Queue.new(all_tiers: true).scope.map(&:name).sort
    assert_equal 2, Leads::Queue.new(all_tiers: true).count
  end
end
