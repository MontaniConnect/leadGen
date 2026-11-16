require "test_helper"

class Imports::HeaderReportTest < ActiveSupport::TestCase
  def report(kind, csv)
    file = Tempfile.new([ "h", ".csv" ])
    file.write(csv)
    file.close
    Imports::HeaderReport.new(kind).call(file.path)
  end

  test "a real-looking Apollo accounts header is accepted and sorted into used and extra columns" do
    result = report(:accounts, "Company Name,Account Stage,# Employees,Website,Company Country,Apollo Account Id,Parent Company,Weird Extra\nA,,5,a.com,US,1,P,x\n")

    assert result.ok?
    assert_empty result.warnings
    assert_includes result.recognised, "# Employees"
    assert_equal [ "Parent Company", "Weird Extra" ], result.unrecognised
  end

  test "renamed but equivalent columns are still recognised" do
    result = report(:accounts, "Name,Employees,Country,Website\nA,5,US,a.com\n")
    assert result.ok?
    assert_empty result.warnings
  end

  test "a file with no company name or no id/website is not an accounts export" do
    no_name = report(:accounts, "Foo,Bar\n1,2\n")
    assert_equal [ "Company Name", "Apollo Account Id or Website" ], no_name.missing_required
    assert_not no_name.ok?

    no_identifier = report(:accounts, "Company Name,# Employees,Company Country\nA,5,US\n")
    assert_equal [ "Apollo Account Id or Website" ], no_identifier.missing_required
  end

  test "missing employees or country columns are warnings that explain the consequence" do
    result = report(:accounts, "Company Name,Website\nA,a.com\n")
    assert result.ok?
    assert_equal [ "No employee-count column found, so every company will fail the size filter.",
                   "No country column found, so every company will fail the country filter." ], result.warnings
  end

  test "a byte-order mark at the start does not hide the first column" do
    result = report(:accounts, "﻿Company Name,Website\nA,a.com\n")
    assert_includes result.recognised, "Company Name"
    assert result.ok?
  end

  test "an empty file has no headers and is not valid" do
    result = report(:accounts, "")
    assert_empty result.headers
    assert_not result.ok?
  end

  test "people exports need an account id and a name" do
    assert report(:people, "First Name,Last Name,Title,Person Linkedin Url,Apollo Account Id\nA,B,CEO,u,1\n").ok?
    result = report(:people, "Company Name,Apollo Account Id\nA,1\n")
    assert_equal [ "First Name or Last Name" ], result.missing_required
    assert_equal [ "Apollo Account Id" ], report(:people, "First Name,Title\nA,CEO\n").missing_required
    assert_equal [ "No Title column found.", "No Person Linkedin Url column found." ], report(:people, "First Name,Apollo Account Id\nA,1\n").warnings
  end
end
