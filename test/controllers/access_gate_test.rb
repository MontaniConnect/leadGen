require "test_helper"

class AccessGateTest < ActionDispatch::IntegrationTest
  include LeadsTestHelper

  setup do
    @original = Rails.configuration.x.require_access_password
    Rails.configuration.x.require_access_password = true
    ENV["APP_PASSWORD"] = "correct horse"
    ENV.delete("APP_USERNAME")
    Scoring::ApiKey.lookup = -> { "sk-test" }
  end

  teardown do
    Rails.configuration.x.require_access_password = @original
    ENV.delete("APP_PASSWORD")
    ENV.delete("APP_USERNAME")
    Scoring::ApiKey.lookup = nil
  end

  def auth(user: "montani", password: "correct horse")
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(user, password) }
  end

  test "without credentials every page asks for a password and shows nothing" do
    lead(name: "Secret Lead")
    [ root_path, dashboard_path, spend_path, results_path, partners_path, exports_path, new_import_path ].each do |path|
      get path
      assert_response :unauthorized, path
      assert_match(/Basic realm=/, response.headers["WWW-Authenticate"])
      assert_no_match(/Secret Lead/, response.body)
    end
  end

  test "the right username and password get in" do
    get root_path, headers: auth
    assert_response :success
    get spend_path, headers: auth
    assert_response :success
  end

  test "a wrong password, a wrong username or an empty password are refused" do
    [ auth(password: "wrong"), auth(user: "admin"), auth(password: ""), auth(password: "correct horse "), auth(password: "CORRECT HORSE") ].each do |headers|
      get root_path, headers: headers
      assert_response :unauthorized
    end
  end

  test "the username can be changed with APP_USERNAME" do
    ENV["APP_USERNAME"] = "carlos"
    get root_path, headers: auth(user: "montani")
    assert_response :unauthorized
    get root_path, headers: auth(user: "carlos")
    assert_response :success
  end

  test "the buttons that spend money and change data are refused too, and do nothing" do
    company_with_pages(name: "Alpha")
    assert_no_enqueued_jobs do
      post pipeline_score_path
      post pipeline_draft_path
      post pipeline_partner_draft_path
      post contact_research_path
    end
    assert_response :unauthorized
    assert_equal 0, PipelineRun.count

    post exports_path, params: { file_format: "csv", scope: "all" }
    assert_response :unauthorized
    assert_equal 0, Export.count
    patch cap_spend_path, params: { amount: "9999" }
    assert_response :unauthorized
    assert_equal 1000, Setting.get("budget.spending_cap_usd"), "the cap cannot be changed without the password"
  end

  test "with credentials the same buttons work" do
    company_with_pages(name: "Alpha")
    assert_enqueued_jobs 1, only: ScoringRunJob do
      post pipeline_score_path, headers: auth
    end
    assert_redirected_to dashboard_path
  end

  test "FAIL CLOSED: with no password configured the app refuses everything, even with credentials" do
    ENV.delete("APP_PASSWORD")
    get root_path
    assert_response :service_unavailable
    assert_match(/Set APP_PASSWORD/, response.body)
    get root_path, headers: auth(password: "")
    assert_response :service_unavailable
    post pipeline_score_path
    assert_response :service_unavailable
    assert_equal 0, PipelineRun.count
  end

  test "the health check stays reachable without a password, so the host can probe it" do
    get rails_health_check_path
    assert_response :success
  end

  test "the gate is off by default in tests and development, so nothing else is affected" do
    Rails.configuration.x.require_access_password = false
    get root_path
    assert_response :success
  end
end
