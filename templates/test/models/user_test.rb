require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes and validates email" do
    user = User.create!(email: "  Person@Example.COM ")
    assert_equal "person@example.com", user.email
    assert_not User.new(email: "not-an-email").valid?
    assert_not User.new(email: "person@example.com").valid?, "duplicate email should be invalid"
  end

  test "newsletter defaults to false and purchased? reflects purchased_at" do
    user = User.create!(email: "a@example.com")
    assert_not user.newsletter?
    assert_not user.purchased?
    user.update!(purchased_at: Time.current)
    assert user.purchased?
  end
end
