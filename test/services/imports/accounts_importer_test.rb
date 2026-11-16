require "test_helper"

class Imports::AccountsImporterTest < ActiveSupport::TestCase
  PATH = Rails.root.join("test/fixtures/files/accounts.csv").to_s

  test "imports valid rows and reports skips with reasons" do
    batch = Imports::AccountsImporter.new(PATH).call

    assert_equal 6, batch.rows_total
    assert_equal 3, batch.rows_created
    assert_equal 1, batch.rows_updated, "the duplicate-website row was folded into Acme"
    assert_equal 2, batch.rows_skipped
    assert_equal({ "missing_name" => 1, "missing_identifier" => 1 }, batch.skip_reasons)
    assert_equal({ "rows_merged_into_existing_company" => 1 }, batch.notes)
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
    assert_equal 4, second.rows_unchanged
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

  # --- automatic merging of duplicate companies ---

  def import_csv(text)
    file = Tempfile.new([ "dupes", ".csv" ])
    file.write(text)
    file.close
    Imports::AccountsImporter.new(file.path).call
  end

  HEADER = "Company Name,# Employees,Website,Company City,Company Country,Industry,Apollo Account Id,Keywords\n".freeze

  test "the same website under a different Apollo id is merged: nothing is overwritten and the other id is remembered" do
    import_csv(HEADER + "Acme Software,45,acme.com,Austin,United States,Software,a1,saas\n" \
                        "Acme Software Group,999,www.ACME.com/about,Dallas,United States,,zz,other\n")

    assert_equal 1, Company.count
    acme = Company.first
    assert_equal [ "Acme Software", 45, "a1", "Austin" ], [ acme.name, acme.employees, acme.apollo_account_id, acme.city ]
    assert_equal [ "zz" ], acme.extra["alternate_apollo_account_ids"]
  end

  test "a merge fills blanks the existing record lacks" do
    import_csv(HEADER + "Acme Software,45,acme.com,Austin,United States,,a1,\n" \
                        "Acme Software,45,acme.com,Austin,United States,Software,zz,saas\n")

    acme = Company.first
    assert_equal [ "Software", "saas", "a1" ], [ acme.industry, acme.keywords, acme.apollo_account_id ]
  end

  test "the same name in the same city and country is merged even with a different website and suffix" do
    batch = import_csv(HEADER + "\"Acme Robotics, Inc.\",30,acme.com,Austin,United States,,x1,\n" \
                                "ACME ROBOTICS Incorporated,31,acme-robots.org,austin,united states,,x2,\n")

    assert_equal 1, Company.count
    assert_equal [ "x2" ], Company.first.extra["alternate_apollo_account_ids"]
    assert_equal 30, Company.first.employees
    assert_equal({ "rows_merged_into_existing_company" => 1 }, batch.notes)
  end

  test "it is strict: a different city, a different country, a missing city or a different name is NOT merged" do
    import_csv(HEADER + "Acme Robotics,30,a.com,Austin,United States,,x1,\n" \
                        "Acme Robotics,30,b.com,Denver,United States,,x2,\n" \
                        "Acme Robotics,30,c.com,Austin,Canada,,x3,\n" \
                        "Acme Robotics,30,d.com,,United States,,x4,\n" \
                        "Acme Robotics Labs,30,e.com,Austin,United States,,x5,\n")

    assert_equal 5, Company.count
  end

  test "a duplicate inside one file merges into the first row" do
    batch = import_csv(HEADER + "Beta Ops,50,beta.io,Denver,United States,,b1,\nBeta Ops LLC,50,beta-ops.com,Denver,United States,,b2,\n")
    assert_equal [ 1, 1 ], [ Company.count, batch.rows_created ]
  end

  test "importing the same duplicate-containing file again changes nothing and keeps the merge quiet" do
    text = HEADER + "Acme Robotics,30,acme.com,Austin,United States,,x1,\nAcme Robotics Inc,30,other.org,Austin,United States,,x2,\n"
    import_csv(text)
    second = import_csv(text)

    assert_equal 1, Company.count
    assert_equal [ 0, 0, 2 ], [ second.rows_created, second.rows_updated, second.rows_unchanged ]
    assert_equal [ "x2" ], Company.first.extra["alternate_apollo_account_ids"], "not added twice"
  end

  test "a merge never touches outreach history already recorded on the existing company" do
    import_csv(HEADER + "Acme Robotics,30,acme.com,Austin,United States,,x1,\n")
    company = Company.first
    company.update!(connection_sent_at: 2.days.ago, reply_result: "interested")
    import_csv(HEADER + "Acme Robotics Inc,30,acme.com,Austin,United States,,x9,\n")

    assert_equal "interested", company.reload.reply_result
    assert_not_nil company.connection_sent_at
    assert_equal 1, Company.count
  end

  test "name keys ignore case, punctuation, accents, 'the' and corporate suffixes" do
    key = Imports::NameKey
    assert_equal "acme", key.call("ACME, Inc.")
    assert_equal "acme", key.call("The Acme Company")
    assert_equal "acmerobotics", key.call("Acme-Robotics LLC")
    assert_equal "cafebonjour", key.call("Café Bonjour Ltd")
    assert_equal "johnsonandjohnson", key.call("Johnson & Johnson")
    assert_equal "inc", key.call("Inc"), "a name that is only a suffix is kept"
    assert_equal "", key.call("  ")
  end
end
