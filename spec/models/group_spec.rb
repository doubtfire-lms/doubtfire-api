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

  it "should know its past members" do
    p = Project.create
    p2 = Project.create

    g1 = FactoryGirl.create(:group)

    g1.add_member p
    g1.add_member p2
    g1.remove_member p

    expect(g1.projects).not_to include(p)
    expect(g1.past_projects).to include(p)
    expect(g1.projects).to include(p2)
    expect(g1.past_projects).not_to include(p2)
    expect(g1.group_memberships.count).to eq(2)
  end
end
