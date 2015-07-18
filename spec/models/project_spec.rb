RSpec.describe Project do

  it "should know its groups" do
  	p = Project.create
  	g1 = FactoryGirl.create(:group)
  	g1.add_member p

  	expect(p.groups).to include(g1)
  end

  it "should only see active groups" do
    p = Project.create
    g1 = FactoryGirl.create(:group)
    g2 = FactoryGirl.create(:group)

    g1.add_member p
    g2.add_member p
    g1.remove_member p

    expect(p.groups).not_to include(g1)
    expect(p.groups).to include(g2)
  end

  it "should know its past groups" do
    p = Project.create
    g1 = FactoryGirl.create(:group)
    g2 = FactoryGirl.create(:group)

    g1.add_member p
    g2.add_member p
    g1.remove_member p

    expect(p.past_groups).to include(g1)
    expect(p.past_groups).not_to include(g2)
  end

end
