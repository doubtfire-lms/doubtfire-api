require "rails_helper"

test "the truth" do
  user = User.first
  puts "hello"
  assert @user.authenticate?("password")
  assert !@user.authenticate?("fsdjkfhdsjk")
end