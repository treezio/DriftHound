require "test_helper"

class InvitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @editor = users(:editor)
    @viewer = users(:viewer)
  end

  # Create tests
  test "admin can create invite" do
    sign_in_as(@admin)
    assert_difference("Invite.count", 1) do
      post invites_path, params: { invite: { email: "newuser@example.com", role: "editor" } }
    end
    assert_redirected_to users_path
    assert_equal "Invite link created successfully.", flash[:notice]

    invite = Invite.last
    assert_equal "newuser@example.com", invite.email
    assert_equal "editor", invite.role
  end

  test "editor cannot create invite" do
    sign_in_as(@editor)
    assert_no_difference("Invite.count") do
      post invites_path, params: { invite: { email: "newuser@example.com", role: "viewer" } }
    end
    assert_redirected_to root_path
  end

  test "viewer cannot create invite" do
    sign_in_as(@viewer)
    assert_no_difference("Invite.count") do
      post invites_path, params: { invite: { email: "newuser@example.com", role: "viewer" } }
    end
    assert_redirected_to root_path
  end

  test "guest cannot create invite" do
    assert_no_difference("Invite.count") do
      post invites_path, params: { invite: { email: "newuser@example.com", role: "viewer" } }
    end
    assert_redirected_to login_path
  end

  test "cannot create invite without email" do
    sign_in_as(@admin)
    assert_no_difference("Invite.count") do
      post invites_path, params: { invite: { role: "viewer" } }
    end
    assert_redirected_to users_path
    assert_equal "Failed to create invite link.", flash[:alert]
  end

  test "cannot create invite for already registered email" do
    sign_in_as(@admin)
    assert_no_difference("Invite.count") do
      post invites_path, params: { invite: { email: @editor.email, role: "viewer" } }
    end
    assert_redirected_to users_path
    assert_equal "Failed to create invite link.", flash[:alert]
  end

  # Destroy tests
  test "admin can delete invite" do
    sign_in_as(@admin)
    invite = Invite.create!(email: "todelete@example.com", role: :viewer, created_by: @admin)
    assert_difference("Invite.count", -1) do
      delete invite_path(invite)
    end
    assert_redirected_to users_path
    assert_equal "Invite deleted.", flash[:notice]
  end

  test "editor cannot delete invite" do
    sign_in_as(@editor)
    invite = Invite.create!(email: "nodelete@example.com", role: :viewer, created_by: @admin)
    assert_no_difference("Invite.count") do
      delete invite_path(invite)
    end
    assert_redirected_to root_path
  end

  test "viewer cannot delete invite" do
    sign_in_as(@viewer)
    invite = Invite.create!(email: "nodelete@example.com", role: :viewer, created_by: @admin)
    assert_no_difference("Invite.count") do
      delete invite_path(invite)
    end
    assert_redirected_to root_path
  end

  private

  def sign_in_as(user)
    post login_path, params: { email: user.email, password: "testpass1" }
  end
end
