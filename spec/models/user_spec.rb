require 'spec_helper'

describe User do
  it "has a valid factory" do
    FactoryGirl.create(:user).should be_valid
  end

  it "is invalid without a first name" do
    FactoryGirl.build(:user, first_name: nil).should_not be_valid
  end

  it "is invalid without a last name" do
    FactoryGirl.build(:user, last_name: nil).should_not be_valid
  end
end