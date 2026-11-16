require "test_helper"

class Imports::PeopleImporterTest < ActiveSupport::TestCase
  PATH = Rails.root.join("test/fixtures/files/people.csv").to_s

  setup { Company.create!(name: "Acme", apollo_account_id: "a1", domain: "acme.com") }

  test "imports contacts joined by Apollo account id" do
    batch = Imports::PeopleImporter.new(PATH).call

    assert_equal 2, batch.rows_created
    assert_equal({ "missing_name" => 1, "unknown_company" => 1 }, batch.skip_reasons)
    assert_equal %w[Ada Grace], Company.first.contacts.order(:id).pluck(:first_name)
    assert_equal "apollo", Contact.first.source
  end

  test "is idempotent" do
    Imports::PeopleImporter.new(PATH).call
    second = Imports::PeopleImporter.new(PATH).call

    assert_equal 2, Contact.count
    assert_equal 0, second.rows_created
    assert_equal 2, second.rows_unchanged
  end
end
