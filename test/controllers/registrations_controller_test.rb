require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @invite = Invite.create!(email: "newuser@example.com", role: :editor, created_by: @admin)
  end

  # New action tests
  test "can view registration form with valid invite" do
    get register_path(token: @invite.token)
    assert_response :success
    assert_select "h1", "Create Account"
  end

  test "registration form shows invited email" do
    get register_path(token: @invite.token)
    assert_response :success
    assert_select "input[value='newuser@example.com'][disabled]"
  end

  test "redirects to login with invalid token" do
    get register_path(token: "invalid-token")
    assert_redirected_to login_path
    assert_equal "Invalid invite link.", flash[:alert]
  end

  test "redirects to login with used invite" do
    @invite.mark_as_used!
    get register_path(token: @invite.token)
    assert_redirected_to login_path
    assert_equal "This invite link has already been used.", flash[:alert]
  end

  test "redirects to login with expired invite" do
    @invite.update!(expires_at: 1.day.ago)
    get register_path(token: @invite.token)
    assert_redirected_to login_path
    assert_equal "This invite link has expired.", flash[:alert]
  end

  test "logged in user is redirected away from registration" do
    sign_in_as(@admin)
    get register_path(token: @invite.token)
    assert_redirected_to root_path
  end

  # Create action tests
  test "can register with valid invite and valid password" do
    assert_difference("User.count", 1) do
      post register_path(token: @invite.token), params: {
        user: {
          password: "testpass1",
          password_confirmation: "testpass1"
        }
      }
    end
    assert_redirected_to root_path
    assert_equal "Welcome to DriftHound! Your account has been created.", flash[:notice]

    user = User.find_by(email: "newuser@example.com")
    assert_not_nil user
    assert_equal "editor", user.role
    assert @invite.reload.used?
  end

  test "user email is set from invite regardless of params" do
    post register_path(token: @invite.token), params: {
      user: {
        email: "attacker@example.com",
        password: "testpass1",
        password_confirmation: "testpass1"
      }
    }
    user = User.last
    assert_equal "newuser@example.com", user.email
    assert_not_equal "attacker@example.com", user.email
  end

  test "user is logged in after registration" do
    post register_path(token: @invite.token), params: {
      user: {
        password: "testpass1",
        password_confirmation: "testpass1"
      }
    }
    assert session[:user_id].present?
  end

  test "cannot register with invalid password" do
    assert_no_difference("User.count") do
      post register_path(token: @invite.token), params: {
        user: {
          password: "short",
          password_confirmation: "short"
        }
      }
    end
    assert_response :unprocessable_entity
    assert_not @invite.reload.used?
  end

  test "cannot register with used invite" do
    @invite.mark_as_used!
    assert_no_difference("User.count") do
      post register_path(token: @invite.token), params: {
        user: {
          password: "testpass1",
          password_confirmation: "testpass1"
        }
      }
    end
    assert_redirected_to login_path
  end

  test "cannot register with expired invite" do
    @invite.update!(expires_at: 1.day.ago)
    assert_no_difference("User.count") do
      post register_path(token: @invite.token), params: {
        user: {
          password: "testpass1",
          password_confirmation: "testpass1"
        }
      }
    end
    assert_redirected_to login_path
  end

  test "assigns viewer role from invite" do
    viewer_invite = Invite.create!(email: "viewerrole@example.com", role: :viewer, created_by: @admin)
    post register_path(token: viewer_invite.token), params: {
      user: {
        password: "testpass1",
        password_confirmation: "testpass1"
      }
    }
    user = User.find_by(email: "viewerrole@example.com")
    assert_equal "viewer", user.role
  end

  test "assigns admin role from invite" do
    admin_invite = Invite.create!(email: "adminrole@example.com", role: :admin, created_by: @admin)
    post register_path(token: admin_invite.token), params: {
      user: {
        password: "testpass1",
        password_confirmation: "testpass1"
      }
    }
    user = User.find_by(email: "adminrole@example.com")
    assert_equal "admin", user.role
  end

  private

  def sign_in_as(user)
    post login_path, params: { email: user.email, password: "testpass1" }
  end
end
