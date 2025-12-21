require "test_helper"

class OauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Enable GitHub OAuth
    Rails.application.config.oauth = {
      github: {
        enabled: true,
        client_id: "test_client_id",
        client_secret: "test_client_secret",
        organization: "test-org",
        team_mappings: {
          admin: "platform-admins",
          editor: "platform-editors",
          viewer: "platform-viewers"
        }
      }
    }
  end

  test "github_redirect redirects to login when OAuth is disabled" do
    Rails.application.config.oauth[:github][:enabled] = false

    get auth_github_path

    assert_redirected_to login_path
    assert_equal "GitHub authentication is not enabled", flash[:alert]
  end

  test "github_redirect sets state in session and redirects to GitHub" do
    get auth_github_path

    assert_response :redirect
    assert response.location.start_with?("https://github.com/login/oauth/authorize")
    assert_includes response.location, "client_id=test_client_id"
    assert_includes response.location, "state="
  end

  test "github callback redirects to login when OAuth is disabled" do
    Rails.application.config.oauth[:github][:enabled] = false

    get auth_github_callback_path, params: { code: "test_code", state: "test_state" }

    assert_redirected_to login_path
    assert_equal "GitHub authentication is not enabled", flash[:alert]
  end

  test "github callback with invalid state redirects to login" do
    # Set a different state in session
    get auth_github_path # This sets session[:oauth_state]

    # Try callback with wrong state
    get auth_github_callback_path, params: { code: "test_code", state: "wrong_state" }

    assert_redirected_to login_path
    assert_equal "Invalid authentication state. Please try again.", flash[:alert]
  end

  test "github callback with organization access error redirects to login" do
    # Set up session state
    get auth_github_path
    state = session[:oauth_state]

    # Mock service to raise OrganizationAccessError
    Oauth::GithubService.any_instance.stubs(:authenticate).raises(
      Oauth::BaseService::OrganizationAccessError.new("Not a member")
    )

    get auth_github_callback_path, params: { code: "test_code", state: state }

    assert_redirected_to login_path
    assert_equal "Access denied. You must be a member of a configured team.", flash[:alert]
  end

  test "github callback with token exchange error redirects to login" do
    get auth_github_path
    state = session[:oauth_state]

    Oauth::GithubService.any_instance.stubs(:authenticate).raises(
      Oauth::BaseService::TokenExchangeError.new("Bad code")
    )

    get auth_github_callback_path, params: { code: "test_code", state: state }

    assert_redirected_to login_path
    assert_equal "GitHub authentication failed. Please try again.", flash[:alert]
  end

  test "successful github callback creates session and redirects to root" do
    user = User.create!(
      email: "test@example.com",
      provider: "github",
      uid: "12345",
      role: :viewer
    )

    get auth_github_path
    state = session[:oauth_state]

    Oauth::GithubService.any_instance.stubs(:authenticate).returns(user)

    get auth_github_callback_path, params: { code: "test_code", state: state }

    assert_redirected_to root_path
    assert_equal "Logged in successfully via GitHub", flash[:notice]
    assert_equal user.id, session[:user_id]
  end

  test "oauth state is cleared after callback" do
    user = User.create!(
      email: "test@example.com",
      provider: "github",
      uid: "12345",
      role: :viewer
    )

    get auth_github_path
    assert_not_nil session[:oauth_state]

    state = session[:oauth_state]
    Oauth::GithubService.any_instance.stubs(:authenticate).returns(user)

    get auth_github_callback_path, params: { code: "test_code", state: state }

    assert_nil session[:oauth_state], "OAuth state should be cleared after use"
  end
end
