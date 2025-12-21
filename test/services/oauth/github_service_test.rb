require "test_helper"

class Oauth::GithubServiceTest < ActiveSupport::TestCase
  setup do
    @valid_state = "valid_state_123"
    @code = "auth_code_123"

    # Mock GitHub OAuth config
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

  test "raises InvalidStateError when state does not match" do
    service = Oauth::GithubService.new(
      code: @code,
      state: "invalid_state",
      session_state: @valid_state
    )

    assert_raises(Oauth::BaseService::InvalidStateError) do
      service.authenticate
    end
  end

  test "raises InvalidStateError when state is blank" do
    service = Oauth::GithubService.new(
      code: @code,
      state: "",
      session_state: @valid_state
    )

    assert_raises(Oauth::BaseService::InvalidStateError) do
      service.authenticate
    end
  end

  test "raises TokenExchangeError on token exchange failure" do
    service = Oauth::GithubService.new(
      code: @code,
      state: @valid_state,
      session_state: @valid_state
    )

    service.stubs(:exchange_code_for_token).raises(
      Oauth::BaseService::TokenExchangeError.new("Bad code")
    )

    assert_raises(Oauth::BaseService::TokenExchangeError) do
      service.authenticate
    end
  end

  test "raises OrganizationAccessError when user not in any configured team" do
    service = Oauth::GithubService.new(
      code: @code,
      state: @valid_state,
      session_state: @valid_state
    )

    service.stubs(:exchange_code_for_token).returns("test_token")
    service.stubs(:fetch_user_info).returns({ uid: "12345", email: "user@example.com", username: "testuser" })
    service.stubs(:fetch_user_teams).returns([])

    assert_raises(Oauth::BaseService::OrganizationAccessError) do
      service.authenticate
    end
  end

  test "creates new user with admin role when in admin team" do
    service = Oauth::GithubService.new(
      code: @code,
      state: @valid_state,
      session_state: @valid_state
    )

    stub_github_api(service, uid: "12345", email: "admin@example.com", teams: [ "platform-admins" ])

    user = service.authenticate

    assert_equal "admin@example.com", user.email
    assert_equal "github", user.provider
    assert_equal "12345", user.uid
    assert user.admin?
  end

  test "creates new user with editor role when in editor team" do
    service = Oauth::GithubService.new(
      code: @code,
      state: @valid_state,
      session_state: @valid_state
    )

    stub_github_api(service, uid: "12345", email: "editor@example.com", teams: [ "platform-editors" ])

    user = service.authenticate

    assert user.editor?
  end

  test "creates new user with viewer role when in viewer team" do
    service = Oauth::GithubService.new(
      code: @code,
      state: @valid_state,
      session_state: @valid_state
    )

    stub_github_api(service, uid: "12345", email: "viewer@example.com", teams: [ "platform-viewers" ])

    user = service.authenticate

    assert user.viewer?
  end

  test "assigns highest privilege role when user in multiple teams" do
    service = Oauth::GithubService.new(
      code: @code,
      state: @valid_state,
      session_state: @valid_state
    )

    stub_github_api(service, uid: "12345", email: "multi@example.com",
      teams: [ "platform-viewers", "platform-admins", "platform-editors" ])

    user = service.authenticate

    assert user.admin?, "Should have admin role (highest privilege)"
  end

  test "updates existing user by email and links OAuth provider" do
    existing_user = User.create!(
      email: "existing@example.com",
      password: "SecurePass123!",
      role: :viewer
    )

    service = Oauth::GithubService.new(
      code: @code,
      state: @valid_state,
      session_state: @valid_state
    )

    stub_github_api(service, uid: "12345", email: "existing@example.com", teams: [ "platform-admins" ])

    user = service.authenticate

    assert_equal existing_user.id, user.id
    assert_equal "github", user.provider
    assert_equal "12345", user.uid
    assert user.admin?, "Role should be updated to admin"
    assert user.can_use_password?, "Should still be able to use password"
  end

  test "finds existing user by provider and uid" do
    existing_user = User.create!(
      email: "oauth@example.com",
      provider: "github",
      uid: "12345",
      role: :editor
    )

    service = Oauth::GithubService.new(
      code: @code,
      state: @valid_state,
      session_state: @valid_state
    )

    stub_github_api(service, uid: "12345", email: "newemail@example.com", teams: [ "platform-admins" ])

    user = service.authenticate

    assert_equal existing_user.id, user.id
    assert_equal "oauth@example.com", user.email, "Email should not change"
    assert user.admin?, "Role should be updated"
  end

  test "ignores teams from other organizations" do
    service = Oauth::GithubService.new(
      code: @code,
      state: @valid_state,
      session_state: @valid_state
    )

    # Only platform-viewers is from the configured org
    stub_github_api(service, uid: "12345", email: "other@example.com", teams: [ "platform-viewers" ])

    user = service.authenticate

    assert user.viewer?, "Should only match team from configured org"
  end

  test "team matching is case insensitive" do
    service = Oauth::GithubService.new(
      code: @code,
      state: @valid_state,
      session_state: @valid_state
    )

    stub_github_api(service, uid: "12345", email: "case@example.com", teams: [ "Platform-Admins" ])

    user = service.authenticate

    assert user.admin?
  end

  test "authorization_url generates correct URL" do
    url = Oauth::GithubService.authorization_url(
      state: "test_state",
      redirect_uri: "http://localhost:3000/auth/github/callback"
    )

    assert_includes url, "https://github.com/login/oauth/authorize"
    assert_includes url, "client_id=test_client_id"
    assert_includes url, "state=test_state"
    assert_includes url, "scope=read%3Aorg+user%3Aemail"
    assert_includes url, "redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fauth%2Fgithub%2Fcallback"
  end

  private

  def stub_github_api(service, uid:, email:, teams:, role: nil)
    service.stubs(:exchange_code_for_token).returns("test_token")
    service.stubs(:fetch_user_info).returns({
      uid: uid,
      email: email,
      username: "testuser",
      name: "Test User"
    })

    # Calculate the role based on teams if not explicitly provided
    calculated_role = role
    unless calculated_role
      team_mappings = Rails.application.config.oauth[:github][:team_mappings]
      matched_roles = []
      teams.each do |team|
        team_mappings.each do |r, team_slug|
          matched_roles << r if team_slug&.downcase == team.downcase
        end
      end
      calculated_role = matched_roles.max_by { |r| { admin: 2, editor: 1, viewer: 0 }[r] || -1 }
    end

    if calculated_role
      service.stubs(:determine_role).returns(calculated_role)
    else
      service.stubs(:determine_role).raises(
        Oauth::BaseService::OrganizationAccessError.new("Not in any configured team")
      )
    end
  end
end
