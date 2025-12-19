require "test_helper"

class InviteTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
  end

  test "generates token automatically" do
    invite = Invite.create!(email: "new@example.com", role: :viewer, created_by: @admin)
    assert_not_nil invite.token
    assert invite.token.length > 20
  end

  test "sets expiration automatically" do
    invite = Invite.create!(email: "new@example.com", role: :viewer, created_by: @admin)
    assert_not_nil invite.expires_at
    assert invite.expires_at > Time.current
    assert invite.expires_at <= 4.days.from_now
  end

  test "token must be unique" do
    invite1 = Invite.create!(email: "user1@example.com", role: :viewer, created_by: @admin)
    invite2 = Invite.new(email: "user2@example.com", role: :editor, created_by: @admin, token: invite1.token)
    assert_not invite2.valid?
    assert_includes invite2.errors[:token], "has already been taken"
  end

  test "email is required" do
    invite = Invite.new(role: :viewer, created_by: @admin)
    assert_not invite.valid?
    assert_includes invite.errors[:email], "can't be blank"
  end

  test "email must be valid format" do
    invite = Invite.new(email: "not-an-email", role: :viewer, created_by: @admin)
    assert_not invite.valid?
    assert_includes invite.errors[:email], "is invalid"
  end

  test "cannot create invite for already registered email" do
    invite = Invite.new(email: @admin.email, role: :viewer, created_by: @admin)
    assert_not invite.valid?
    assert_includes invite.errors[:email], "is already registered"
  end

  test "available scope returns only unused and unexpired invites" do
    available = Invite.create!(email: "available@example.com", role: :viewer, created_by: @admin)
    used = Invite.create!(email: "used@example.com", role: :editor, created_by: @admin, used_at: Time.current)
    expired = Invite.create!(email: "expired@example.com", role: :admin, created_by: @admin, expires_at: 1.day.ago)

    available_invites = Invite.available
    assert_includes available_invites, available
    assert_not_includes available_invites, used
    assert_not_includes available_invites, expired
  end

  test "available? returns true for unused and unexpired invite" do
    invite = Invite.create!(email: "new@example.com", role: :viewer, created_by: @admin)
    assert invite.available?
  end

  test "available? returns false for used invite" do
    invite = Invite.create!(email: "new@example.com", role: :viewer, created_by: @admin, used_at: Time.current)
    assert_not invite.available?
  end

  test "available? returns false for expired invite" do
    invite = Invite.create!(email: "new@example.com", role: :viewer, created_by: @admin, expires_at: 1.day.ago)
    assert_not invite.available?
  end

  test "used? returns true when used_at is present" do
    invite = Invite.create!(email: "new@example.com", role: :viewer, created_by: @admin, used_at: Time.current)
    assert invite.used?
  end

  test "expired? returns true when expires_at is in the past" do
    invite = Invite.create!(email: "new@example.com", role: :viewer, created_by: @admin, expires_at: 1.day.ago)
    assert invite.expired?
  end

  test "mark_as_used! sets used_at" do
    invite = Invite.create!(email: "new@example.com", role: :viewer, created_by: @admin)
    assert_nil invite.used_at
    invite.mark_as_used!
    assert_not_nil invite.used_at
  end

  test "supports all roles" do
    %w[viewer editor admin].each_with_index do |role, i|
      invite = Invite.create!(email: "role#{i}@example.com", role: role, created_by: @admin)
      assert_equal role, invite.role
    end
  end
end
