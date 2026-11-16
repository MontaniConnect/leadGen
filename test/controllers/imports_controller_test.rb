require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  ACCOUNTS = Rails.root.join("test/fixtures/files/accounts.csv").to_s
  PEOPLE = Rails.root.join("test/fixtures/files/people.csv").to_s
  PILOT = Rails.root.join("test/fixtures/files/pilot_accounts.csv").to_s

  # A fixture path, or literal CSV text (uploaded under `name`).
  def csv(path_or_text, name: "upload.csv")
    file = File.exist?(path_or_text) ? path_or_text : nil
    io = file ? File.open(file, "rb") : StringIO.new(path_or_text)
    Rack::Test::UploadedFile.new(io, "text/csv", original_filename: file ? File.basename(file) : name)
  end

  def upload_accounts(file, **params) = post(import_accounts_path, params: { file: file, mode: "all" }.merge(params))

  test "the upload page explains what happens and offers a sample or everything" do
    get new_import_path
    assert_response :success
    assert_select "label[for=accounts_file]", text: "Apollo accounts CSV"
    assert_select "input[type=radio][value=sample][checked]"
    assert_select "input[type=radio][value=all]"
    assert_select "label[for=sample_size]", text: "Rows in the sample"
    assert_select "label[for=people_file]", text: "Apollo people CSV"
    assert_select ".hint", text: /no paid calls are made/
  end

  test "all rows: imports, runs the prefilter, shows the counts and the skip reasons" do
    upload_accounts(csv(ACCOUNTS))

    assert_redirected_to dashboard_path
    assert_equal 3, Company.count
    assert_match(/Imported accounts\.csv: 6 rows read, 3 new, 1 updated, 0 unchanged, 2 skipped/, flash[:notice])
    assert_match(/missing name: 1/, flash[:notice])
    assert_match(/1 row was a duplicate of an existing company and was merged into it/, flash[:notice])
    assert_match(/Prefilter: 1 pass, 2 fail\./, flash[:notice])
    assert_equal "accounts.csv", ImportBatch.last.filename, "the uploaded file's own name, not a temp name"
    assert_equal 0, Company.where(prefilter_status: "pending").count
  end

  test "the dashboard it lands on shows the decisions and reasons" do
    upload_accounts(csv(ACCOUNTS))
    follow_redirect!
    assert_select ".flash", text: /Prefilter: 1 pass, 2 fail/
    assert_select "td", text: "employees_above_max"
    assert_select "td", text: "excluded_keyword: staffing"
  end

  test "a random sample imports only that many rows and remembers them as the pilot" do
    post import_accounts_path, params: { file: csv(PILOT), mode: "sample", sample_size: "10" }

    assert_redirected_to dashboard_path
    assert_equal 10, Company.count
    assert_equal 10, Pilot.scope.count
    assert_match(/10 rows read, 10 new/, flash[:notice])
    assert_match(/Prefilter: \d+ pass, \d+ fail/, flash[:notice])
  end

  test "the same sample is chosen every time, and a blank size means 20" do
    post import_accounts_path, params: { file: csv(PILOT), mode: "sample", sample_size: "8" }
    first = Company.pluck(:name).sort
    Company.destroy_all
    post import_accounts_path, params: { file: csv(PILOT), mode: "sample", sample_size: "8" }
    assert_equal first, Company.pluck(:name).sort

    Company.destroy_all
    post import_accounts_path, params: { file: csv(PILOT), sample_size: "" }
    assert_equal 20, Company.count
  end

  test "the sample size is kept within sensible bounds" do
    post import_accounts_path, params: { file: csv(PILOT), mode: "sample", sample_size: "0" }
    assert_equal 20, Company.count
    Company.destroy_all
    post import_accounts_path, params: { file: csv(PILOT), mode: "sample", sample_size: "999999" }
    assert_equal 40, Company.count, "capped at the file's 40 rows (and at imports.max_sample_rows)"
  end

  test "re-uploading the same file creates nothing new" do
    upload_accounts(csv(ACCOUNTS))
    upload_accounts(csv(ACCOUNTS))
    assert_match(/0 new, 0 updated, 4 unchanged/, flash[:notice])
    assert_equal 3, Company.count
  end

  test "the wrong kind of file is refused, naming what is missing and what was found" do
    upload_accounts(csv("Foo,Bar,Baz\n1,2,3\n", name: "notes.csv"))

    assert_redirected_to new_import_path
    assert_match(/doesn't look like an Apollo accounts export/, flash[:alert])
    assert_match(/Missing: Company Name; Apollo Account Id or Website/, flash[:alert])
    assert_match(/Columns found: Foo, Bar, Baz/, flash[:alert])
    assert_equal 0, Company.count
    assert_equal 0, ImportBatch.count
  end

  test "a people file uploaded as accounts is refused, and the reverse" do
    upload_accounts(csv(PEOPLE))
    assert_match(/Missing: Company Name/, flash[:alert])

    post import_people_path, params: { file: csv(ACCOUNTS) }
    assert_match(/doesn't look like an Apollo people export/, flash[:alert])
    assert_match(/Missing: First Name or Last Name/, flash[:alert])
    assert_equal 0, Contact.count
  end

  test "a file without an employees column imports but warns that everything will fail the size filter" do
    upload_accounts(csv("Company Name,Website,Company Country\nAcme,acme.com,United States\n"))

    assert_equal 1, Company.count
    assert_match(/every company will fail the size filter/, flash[:notice])
    assert_match(/Prefilter: 0 pass, 1 fail/, flash[:notice])
    assert_equal [ "employees_unknown" ], Company.first.prefilter_reasons
  end

  test "a file with headers but no rows is refused" do
    upload_accounts(csv("Company Name,Website\n"))
    assert_equal "The file has a header row but no company rows.", flash[:alert]
  end

  test "no file, a non-CSV file and an oversized file are refused with a message" do
    post import_accounts_path
    assert_equal "Choose a CSV file first.", flash[:alert]

    post import_accounts_path, params: { file: csv("x", name: "export.xlsx") }
    assert_equal "Only .csv files can be imported.", flash[:alert]

    Setting.set("imports.max_upload_mb", 0.00001)
    post import_accounts_path, params: { file: csv(ACCOUNTS) }
    assert_match(/over 1.0e-05 MB|over .* MB/, flash[:alert])
    assert_equal 0, Company.count
  end

  test "a file that breaks half-way is reported, keeps what was read, and is not left 'running'" do
    upload_accounts(csv("Company Name,Website,# Employees\nGood Co,good.com,50\n\"broken,row\n", name: "bad.csv"))

    assert_redirected_to new_import_path
    assert_match(/could not be read as a CSV/, flash[:alert])
    assert_equal "failed", ImportBatch.last.status
  end

  test "people: import after accounts matches by Apollo Account Id and chooses contacts by title" do
    upload_accounts(csv(ACCOUNTS))
    post import_people_path, params: { file: csv(PEOPLE) }

    assert_redirected_to dashboard_path
    assert_equal 2, Contact.count
    assert_match(/Imported people\.csv: 4 rows read, 2 new/, flash[:notice])
    assert_match(/missing name: 1, unknown company: 1/, flash[:notice])
    assert_match(/Contacts: 1 companies have a contact, 1 do not\./, flash[:notice]) # the other is Gamma Staffing, a partner candidate
    assert_equal "Ada", Company.find_by!(apollo_account_id: "a1").selected_contact.first_name
  end

  test "people imported before any accounts are all skipped, not lost silently" do
    post import_people_path, params: { file: csv(PEOPLE) }
    assert_match(/0 new/, flash[:notice])
    assert_match(/unknown company: 3/, flash[:notice])
  end

  test "recent imports are listed with their counts and skip reasons" do
    upload_accounts(csv(ACCOUNTS))
    get new_import_path
    assert_select "#recent-heading + table td", text: "accounts.csv"
    assert_select "#recent-heading + table td", text: /missing name: 1/
  end

  test "the queue and empty state point to the upload page" do
    get root_path
    assert_select ".empty a[href='#{new_import_path}']", text: "Import your Apollo file"
    assert_select "a[href='#{new_import_path}']", text: "Import Apollo file"
  end
end
