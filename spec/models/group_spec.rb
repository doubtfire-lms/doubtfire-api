require 'spec_helper'

RSpec.describe Group do

  it "should have group members" do
  	p = Project.create
  	g1 = FactoryGirl.create(:group)
  	expect(g1).to be_valid

  	g1.add_member p

  	expect(g1.projects).to include(p)
  end

  it "should not show inactive members" do
  	p = Project.create
  	g1 = FactoryGirl.create(:group)
  	expect(g1).to be_valid

  	g1.add_member p
  	g1.remove_member p

  	expect(g1.projects).not_to include(p)
  end

  it "should allow students to rejoin groups" do
  	p = Project.create
  	g1 = FactoryGirl.create(:group)
  	expect(g1).to be_valid

  	g1.add_member p
  	g1.remove_member p
  	g1.add_member p


  	expect(g1.projects).to include(p)
  	expect(g1.group_memberships.count).to eq(1)
  end

end
