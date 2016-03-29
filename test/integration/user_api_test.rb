require "test_helper"

class UserApiTest < ActiveSupport::TestCase

  setup do
    # Make it Andrew Cain from seeds.db
      @user = User.first
  end

  test "does run" do
    puts "here\n"
    assert      true
  end
end
