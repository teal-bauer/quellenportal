require "test_helper"

class Admin::MeilisearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @auth = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(
      Rails.application.credentials.dig(:admin, :username) || "admin",
      Rails.application.credentials.dig(:admin, :password)
    )}
  end

  test "start_import creates ImportRun and redirects" do
    assert_difference "ImportRun.count", 1 do
      post admin_start_import_path, headers: @auth
    end

    run = ImportRun.last
    assert_equal "pending", run.status
    assert_not_nil run.started_at
    assert_redirected_to admin_status_path
  end

  test "start_import rejects when import already active" do
    ImportRun.create!(status: "importing", started_at: Time.current)

    assert_no_difference "ImportRun.count" do
      post admin_start_import_path, headers: @auth
    end

    assert_redirected_to admin_status_path
    assert_equal "An import is already running.", flash[:alert]
  end

  test "cancel_import cancels active run" do
    run = ImportRun.create!(status: "importing", started_at: Time.current)
    post admin_cancel_import_path, headers: @auth

    run.reload
    assert_equal "cancelled", run.status
    assert_not_nil run.finished_at
    assert_redirected_to admin_status_path
  end

  test "cancel_import with no active run" do
    post admin_cancel_import_path, headers: @auth
    assert_redirected_to admin_status_path
    assert_equal "No active import to cancel.", flash[:alert]
  end

  test "unauthenticated requests are rejected" do
    post admin_start_import_path
    assert_response :unauthorized
  end
end
