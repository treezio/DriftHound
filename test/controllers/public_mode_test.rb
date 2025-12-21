require "test_helper"

class PublicModeTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production", status: :ok)
    @environment.drift_checks.create!(
      status: :ok,
      add_count: 0,
      change_count: 0,
      destroy_count: 0,
      raw_output: "No changes"
    )
    @user = users(:admin)
  end

  # ===== Private Mode (default) Tests =====

  test "dashboard requires login when public mode is disabled" do
    Rails.application.config.public_mode = false

    get root_path
    assert_redirected_to login_path
    assert_equal "You must be logged in to perform this action", flash[:alert]
  end

  test "project page requires login when public mode is disabled" do
    Rails.application.config.public_mode = false

    get project_path(@project.key)
    assert_redirected_to login_path
  end

  test "environment page requires login when public mode is disabled" do
    Rails.application.config.public_mode = false

    get project_environment_path(@project.key, @environment.key)
    assert_redirected_to login_path
  end

  test "logged in user can access dashboard when public mode is disabled" do
    Rails.application.config.public_mode = false

    post login_path, params: { email: @user.email, password: "testpass1" }
    get root_path
    assert_response :success
  end

  test "logged in user can access project when public mode is disabled" do
    Rails.application.config.public_mode = false

    post login_path, params: { email: @user.email, password: "testpass1" }
    get project_path(@project.key)
    assert_response :success
  end

  test "logged in user can access environment when public mode is disabled" do
    Rails.application.config.public_mode = false

    post login_path, params: { email: @user.email, password: "testpass1" }
    get project_environment_path(@project.key, @environment.key)
    assert_response :success
  end

  # ===== Public Mode Tests =====

  test "dashboard is accessible without login when public mode is enabled" do
    Rails.application.config.public_mode = true

    get root_path
    assert_response :success
  end

  test "project page is accessible without login when public mode is enabled" do
    Rails.application.config.public_mode = true

    get project_path(@project.key)
    assert_response :success
  end

  test "environment page is accessible without login when public mode is enabled" do
    Rails.application.config.public_mode = true

    get project_environment_path(@project.key, @environment.key)
    assert_response :success
  end

  # ===== Admin Actions Always Require Auth =====

  test "delete project requires login even in public mode" do
    Rails.application.config.public_mode = true

    delete project_path(@project.key)
    assert_redirected_to login_path
  end

  test "delete environment requires login even in public mode" do
    Rails.application.config.public_mode = true

    delete project_environment_path(@project.key, @environment.key)
    assert_redirected_to login_path
  end

  test "users page requires login even in public mode" do
    Rails.application.config.public_mode = true

    get users_path
    assert_redirected_to login_path
  end

  test "api tokens page requires login even in public mode" do
    Rails.application.config.public_mode = true

    get api_tokens_path
    assert_redirected_to login_path
  end

  test "invites page requires login even in public mode" do
    Rails.application.config.public_mode = true

    get users_path # invites are on users page
    assert_redirected_to login_path
  end

  # ===== Helper Method Tests =====

  test "public_mode? helper returns correct value" do
    Rails.application.config.public_mode = true
    get root_path
    # We can't directly test the helper, but we can verify behavior
    assert_response :success

    Rails.application.config.public_mode = false
    get root_path
    assert_redirected_to login_path
  end

  teardown do
    # Reset to default (private mode)
    Rails.application.config.public_mode = false
  end
end
