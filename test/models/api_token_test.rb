require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "requires name" do
    token = ApiToken.new
    token.valid?
    assert_includes token.errors[:name], "can't be blank"
  end

  test "generates token automatically" do
    token = ApiToken.create!(name: "test-token")
    assert_not_nil token.token
    assert token.token.length >= 20
  end

  test "token must be unique" do
    first = ApiToken.create!(name: "first")
    second = ApiToken.new(name: "second", token: first.token)
    assert_not second.valid?
    assert_includes second.errors[:token], "has already been taken"
  end

  test "authenticate returns token when valid" do
    token = ApiToken.create!(name: "test-token")
    found = ApiToken.authenticate(token.token)
    assert_equal token.id, found.id
  end

  test "authenticate returns nil when invalid" do
    found = ApiToken.authenticate("invalid-token")
    assert_nil found
  end

  test "authenticate returns nil when nil" do
    found = ApiToken.authenticate(nil)
    assert_nil found
  end
end
