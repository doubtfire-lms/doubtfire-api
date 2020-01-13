require "rails_helper"

RSpec.describe GroupSet do

  it "should be valid from factory" do
  	gs = FactoryBot.create(:group_set)
  	expect(gs).to be_valid
  end

  it "should exist within its unit" do
  	unit = FactoryBot.create(:unit)
  	gs = FactoryBot.create(:group_set, unit: unit)

  	expect(unit.group_sets).to include(gs)
  end

end
