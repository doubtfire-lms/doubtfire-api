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
      password: "freddy",
      email: "test@test.org",
      username: "metoo",
      password: 'potato123',
      password_confirmation: 'potato123'
    }
    User.create!(profile)
    assert User.last, profile
  end

  test "has a valid factory" do
    assert (FactoryGirl.create(:user))
  end

  test "a user is invalid without a first name" do
    assert_not FactoryGirl.build(:user, first_name: nil).valid?
  end

  it "a user is invalid without a last name" do
    assert_not FactoryGirl.build(:user, last_name: nil).valid?
  end

end
