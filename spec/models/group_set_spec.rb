require "rails_helper"

RSpec.describe GroupSet do

  it "should be valid from factory" do
  	gs = FactoryGirl.create(:group_set, with_students: false)
  	expect(gs).to be_valid
  end

  it "should exist within its unit" do
  	unit = FactoryGirl.create(:unit, with_students: false)
  	gs = FactoryGirl.create(:group_set, unit: unit)

  	expect(unit.group_sets).to include(gs)
  end

end
