require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user with compliant password" do
    user = User.new(email: "test@example.com", password: "secure123", role: :viewer)
    assert user.valid?
  end

  test "password must be at least 8 characters" do
    user = User.new(email: "test@example.com", password: "short1", role: :viewer)
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "password must include at least one letter" do
    user = User.new(email: "test@example.com", password: "12345678", role: :viewer)
    assert_not user.valid?
    assert_includes user.errors[:password], "must include at least one letter and one number"
  end

  test "password must include at least one number" do
    user = User.new(email: "test@example.com", password: "abcdefgh", role: :viewer)
    assert_not user.valid?
    assert_includes user.errors[:password], "must include at least one letter and one number"
  end

  test "password cannot be same as email username" do
    user = User.new(email: "testuser@example.com", password: "testuser", role: :viewer)
    assert_not user.valid?
    assert_includes user.errors[:password], "cannot be the same as your email"
  end

  test "password cannot be a common password" do
    user = User.new(email: "test@example.com", password: "password123", role: :viewer)
    assert_not user.valid?
    assert_includes user.errors[:password], "is too common, please choose a more secure password"
  end

  test "common password check is case insensitive" do
    user = User.new(email: "test@example.com", password: "PASSWORD123", role: :viewer)
    assert_not user.valid?
    assert_includes user.errors[:password], "is too common, please choose a more secure password"
  end

  test "allows valid complex password" do
    user = User.new(email: "test@example.com", password: "MySecure99", role: :viewer)
    assert user.valid?
  end

  test "email username check is case insensitive" do
    user = User.new(email: "TestUser@example.com", password: "TESTUSER", role: :viewer)
    assert_not user.valid?
    assert_includes user.errors[:password], "cannot be the same as your email"
  end
end
