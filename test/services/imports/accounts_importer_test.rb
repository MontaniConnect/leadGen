require "test_helper"

class Imports::AccountsImporterTest < ActiveSupport::TestCase
  PATH = Rails.root.join("test/fixtures/files/accounts.csv").to_s

  test "imports valid rows and reports skips with reasons" do
    batch = Imports::AccountsImporter.new(PATH).call

    assert_equal 6, batch.rows_total
    assert_equal 3, batch.rows_created
    assert_equal 3, batch.rows_skipped
    assert_equal({ "missing_name" => 1, "missing_identifier" => 1, "duplicate_domain" => 1 }, batch.skip_reasons)
    assert_equal 3, Company.count
  end

  test "parses fields" do
    Imports::AccountsImporter.new(PATH).call
    acme = Company.find_by!(apollo_account_id: "a1")

    assert_equal "acme.com", acme.domain
    assert_equal 45, acme.employees
    assert_equal 5_000_000, acme.total_funding
    assert_equal 2_500_000, acme.annual_revenue
    assert_equal Date.new(2026, 10, 1), acme.last_raised_at
    assert_equal "Acme Holdings", acme.extra["Parent Company"]
    assert_equal 1200, Company.find_by!(apollo_account_id: "b2").employees
  end

  test "re-importing the same file creates no duplicates" do
    Imports::AccountsImporter.new(PATH).call
    second = Imports::AccountsImporter.new(PATH).call

    assert_equal 3, Company.count
    assert_equal 0, second.rows_created
    assert_equal 0, second.rows_updated
    assert_equal 3, second.rows_unchanged
  end

  test "updates a changed row instead of duplicating" do
    Imports::AccountsImporter.new(PATH).call
    Company.find_by!(apollo_account_id: "a1").update!(employees: 10)
    batch = Imports::AccountsImporter.new(PATH).call

    assert_equal 1, batch.rows_updated
    assert_equal 45, Company.find_by!(apollo_account_id: "a1").employees
  end

  test "matches by domain when the existing company has no Apollo id" do
    existing = Company.create!(name: "Old Acme", domain: "acme.com")
    Imports::AccountsImporter.new(PATH).call

    assert_equal "a1", existing.reload.apollo_account_id
    assert_equal 1, Company.where(domain: "acme.com").count
  end

  test "summary is readable" do
    batch = Imports::AccountsImporter.new(PATH).call
    text = Imports::Summary.new(batch).to_s

    assert_includes text, "created:    3"
    assert_includes text, "missing_name: 1"
  end
end
