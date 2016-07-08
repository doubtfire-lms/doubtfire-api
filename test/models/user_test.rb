require "test_helper"

class UserTest < ActiveSupport::TestCase

  setup do
    # Make it Andrew Cain
    @user = User.first
  end

  test "user authentication post" do
    assert      @user.authenticate? 'password'
    assert_not  @user.authenticate? 'potato'
  end

  test "user authentication put" do
    # Get clarification for testing requirements
  end

  test "create user" do
    profile = {
      first_name: "Test",
      last_name: "Test",
      nickname: "Test",
      role_id: 1,
      email: "test@test.org",
      username: "metoo",
      password: 'potato123',
      password_confirmation: 'potato123'
    }
    User.create!(profile)
    assert User.last, profile
  end

end
