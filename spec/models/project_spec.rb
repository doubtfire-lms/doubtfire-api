require "rails_helper"

RSpec.describe Project do

  it "should know its groups" do
  	p = Project.create
  	g1 = FactoryBot.create(:group)
  	g1.add_member p

  	expect(p.groups).to include(g1)
  end

  it "should only see active groups" do
    p = Project.create
    g1 = FactoryBot.create(:group)
    g2 = FactoryBot.create(:group)

    g1.add_member p
    g2.add_member p
    g1.remove_member p

    expect(p.groups).not_to include(g1)
    expect(p.groups).to include(g2)
  end

  it "should know its past groups" do
    p = Project.create
    g1 = FactoryBot.create(:group)
    g2 = FactoryBot.create(:group)

    g1.add_member p
    g2.add_member p
    g1.remove_member p

    expect(p.past_groups).to include(g1)
    expect(p.past_groups).not_to include(g2)
  end

  it "can locate a matching task from another project" do
    unit = FactoryBot.create(:unit, student_count:2)
    u1 = unit.students[0]
    u2 = unit.students[1]

    p1 = unit.enrol_student u1
    p2 = unit.enrol_student u2

    t2 = p2.tasks.first
    t1 = p1.matching_task t2

    expect(t1.task_definition).to eq(t2.task_definition)
  end

end
