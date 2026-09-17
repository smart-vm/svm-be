require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid with an email and password" do
    user = User.new(email: "new_user@example.com", password: "password123", password_confirmation: "password123")
    assert user.valid?
  end

  test "requires an email" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires a unique email" do
    user = User.new(email: users(:one).email, password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "requires a password on creation" do
    user = User.new(email: "no_password@example.com")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end
end
