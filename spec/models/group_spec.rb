require "rails_helper"

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

  it "should exist from unit factory" do
    unit = FactoryGirl.create(:unit, group_sets: 1, student_count: 2, :groups => [ { gs: 0, students: 2} ])
    expect(unit).to be_valid
    expect(unit.group_sets[0].groups.count).to eq(1)
    expect(unit.group_sets[0].groups[0].projects.count).to eq(2)
  end

  it "should allow multiple group creations in factory" do
    unit = FactoryGirl.create(:unit, group_sets: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ])

    expect(unit).to be_valid
    expect(unit.group_sets[0].groups.count).to eq(2)
    expect(unit.group_sets[0].groups[0].projects.count).to eq(2)
    expect(unit.group_sets[0].groups[1].projects.count).to eq(2)

    expect(unit.group_sets[0].groups[0].projects).to include(unit.projects[0])
    expect(unit.group_sets[0].groups[0].projects).to include(unit.projects[1])
    expect(unit.group_sets[0].groups[0].projects).not_to include(unit.projects[2])
    expect(unit.group_sets[0].groups[0].projects).not_to include(unit.projects[3])

    expect(unit.group_sets[0].groups[1].projects).not_to include(unit.projects[0])
    expect(unit.group_sets[0].groups[1].projects).not_to include(unit.projects[1])
    expect(unit.group_sets[0].groups[1].projects).to include(unit.projects[2])
    expect(unit.group_sets[0].groups[1].projects).to include(unit.projects[3])
  end

  it "should accept group submissions" do
    unit = FactoryGirl.create(:unit, group_sets: 1, student_count: 2, :groups => [ { gs: 0, students: 2} ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first
    p2_t1 = p2.tasks.first

    submission = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]

    p1_t1 = p1.tasks.first
    p2_t1 = p2.tasks.first

    expect(p1_t1.contribution_pct).to eq(50)
    expect(p1_t1.group_submission).to eq(submission)

    expect(p2_t1.contribution_pct).to eq(50)
    expect(p2_t1.group_submission).to eq(submission)
  end

  it "should fail if not all projects are in the group" do
    unit = FactoryGirl.create(:unit, group_sets: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p_other = unit.projects.last

    p1_t1 = p1.tasks.first

    expect {
      grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p_other, pct: 50} ]
    }.to raise_error("Not all contributions were from team members.")

    p1_t1 = p1.tasks.first

    expect(p1_t1.contribution_pct).to eq(100)
    expect(p1_t1.group_submission).to eq(nil)
  end

  it "should fail if total pct is out of range 100 +/- 10" do
    unit = FactoryGirl.create(:unit, group_sets: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first

    expect {
      submission = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 150} ]
    }.to raise_error("Contribution percentages are excessive.")

    expect {
      submission = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 10} ]
    }.to raise_error("Contribution percentages are insufficient.")

    p1_t1 = p1.tasks.first

    expect(p1_t1.contribution_pct).to eq(100)
    expect(p1_t1.group_submission).to eq(nil)
  end
end
