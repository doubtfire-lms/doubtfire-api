require "rails_helper"

RSpec.describe User do
  it "has a valid factory" do
    expect(FactoryBot.create(:user)).to be_valid
  end

  it "is invalid without a first name" do
    expect(FactoryBot.build(:user, first_name: nil)).not_to be_valid
  end

  it "is invalid without a last name" do
    expect(FactoryBot.build(:user, last_name: nil)).not_to be_valid
  end
end
