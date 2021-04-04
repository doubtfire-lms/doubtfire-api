require "rails_helper"

RSpec.describe Group do

  it "should exist from unit factory" do
    unit = FactoryBot.create(:unit, group_sets: 1, student_count: 2, :groups => [ { gs: 0, students: 2} ])
    expect(unit).to be_valid
    expect(unit.group_sets[0].groups.count).to eq(1)
    expect(unit.group_sets[0].groups[0].projects.count).to eq(2)
  end

  it "should allow multiple group creations in factory" do
    unit = FactoryBot.create(:unit, group_sets: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ])

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

it "should know its members" do
    unit = FactoryBot.create(:unit, group_sets: 1, student_count: 2, :groups => [ { gs: 0, students: 2} ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p2 = grp.projects.last

    expect(grp.has_user p1.student).to be true
    expect(grp.has_user p2.student).to be true
    expect(grp.has_user unit.convenors.first).to be false
  end

  it "should accept group submissions" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first

    submission = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]

    p2_t1 = p2.tasks.first

    expect(p1_t1.contribution_pct).to eq(50)
    expect(p1_t1.group_submission).to eq(submission)

    expect(p2_t1.contribution_pct).to eq(50)
    expect(p2_t1.group_submission).to eq(submission)
  end

  it "should fail if not all projects are in the group" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p_other = unit.projects.last

    p1_t1 = p1.tasks.first

    expect {
      grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p_other, pct: 50} ]
    }.to raise_error("Not all contributions were from team members.")

    expect(p1_t1.contribution_pct).to eq(100)
    expect(p1_t1.group_submission).to eq(nil)
  end

  it "should fail on submission if this is not a group task" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 2, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups[0]

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks[1]
    if p1_t1.task_definition.group_set
      p1_t1 = p1.tasks[0]
    end

    expect(p1_t1.task_definition.group_set).to eq(nil)

    expect {
      grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]
    }.to raise_error("Group submission only allowed for group tasks.")

    expect(p1_t1.contribution_pct).to eq(100)
    expect(p1_t1.group_submission).to eq(nil)
  end

  it "should fail on submission if submitted to wrong group" do
    unit = FactoryBot.create(:unit, group_sets: 2, task_count: 2, student_count: 4,
        :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2}, {gs: 1, students: 2}, {gs: 1, students: 2} ],
        :group_tasks => [ { gs: 0, idx: 0 }, { gs: 1, idx: 1} ])

    grp0 = unit.group_sets[0].groups[0]
    grp1 = unit.group_sets[1].groups[0]

    p0 = grp0.projects[0]
    p1 = grp0.projects[1]

    p0_t0 = p1.tasks[0] # task for group 1

    if p0_t0.task_definition.group_set == grp1.group_set
      test_grp = grp0
    else
      test_grp = grp1
    end

    expect(p0_t0.task_definition.group_set).not_to eq(test_grp.group_set)

    expect {
      test_grp.create_submission p0_t0, "Group has submitted its awesome work", [ { project: p0, pct: 50}, { project: p1, pct: 50} ]
    }.to raise_error("Group submission for wrong group for unit.")

    expect(p0_t0.contribution_pct).to eq(100)
    expect(p0_t0.group_submission).to eq(nil)
  end

  it "should fail if total pct is out of range 100 +/- 10" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

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

    expect(p1_t1.contribution_pct).to eq(100)
    expect(p1_t1.group_submission).to eq(nil)
  end

  it "should trigger submission state across tasks in the group" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first

    submission = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]

    p1_t1.trigger_transition( trigger: "rtm", by_user:unit.convenors.first.user)

    p2_t1 = p2.tasks.first

    expect(p1_t1.task_status).to eq(TaskStatus.ready_to_mark)
    expect(p2_t1.task_status).to eq(TaskStatus.ready_to_mark)
  end

  it "should allow students to trigger submission state across tasks in the group" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1,
      student_count: 2,
      :groups => [ { gs: 0, students: 2} ],
      :group_tasks => [ { gs: 0, idx: 0 } ] )

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first

    submission = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]

    p1_t1.trigger_transition( trigger: "rtm", by_user: p1.student )

    p2_t1 = p2.tasks.first

    expect(p1_t1.task_status).to eq(TaskStatus.ready_to_mark)
    expect(p2_t1.task_status).to eq(TaskStatus.ready_to_mark)
  end

  it "should allow not trigger working and help state across tasks in the group" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first

    submission = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]

    p1_t1.trigger_transition( trigger: "working_on_it", by_user: p1.student )

    p2_t1 = p2.tasks.first

    expect(p1_t1.task_status).to eq(TaskStatus.working_on_it)
    expect(p2_t1.task_status).to eq(TaskStatus.not_started)
  end

  it "should trigger events even without a group submission" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 2, :groups => [ { gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first

    p1_t1.trigger_transition( trigger: "rtm", by_user: p1.student )

    p2_t1 = p2.tasks.first

    expect(p1_t1.task_status).to eq(TaskStatus.ready_to_mark)
    expect(p2_t1.task_status).to eq(TaskStatus.ready_to_mark)
  end

  it "should ensure that group submissions are not duplicated" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first

    sub1 = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]

    # ensure it is reloaded
    sub2 = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 25}, { project: p2, pct: 75} ]

    expect(sub1).to eq(sub2)
  end

  it "should ensure that group submissions are duplicated if group membership has changed" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 2, :groups => [ { gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first

    sub1 = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]

    grp.remove_member p2

    # ensure it is reloaded
    sub2 = grp.create_submission p1_t1, "New group submission", [ { project: p1, pct: 100 } ]

    expect(sub1).not_to eq(sub2)
  end

  it "should allow new submissions for members who change groups" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, {gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups[0]
    other_grp = unit.group_sets[0].groups[1]

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first

    sub1 = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]

    other_grp.add_member p1

    # ensure it is reloaded
    sub2 = other_grp.create_submission p1_t1, "New group submission", [ { project: p1, pct: 30 }, { project: other_grp.projects.first, pct: 40 }, { project: other_grp.projects.last, pct: 30} ]

    expect(sub1).not_to eq(sub2)
  end

  it "should change group even when there is an existing submission" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, {gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups[0]
    other_grp = unit.group_sets[0].groups[1]

    p1 = grp.projects.first
    p2 = grp.projects.last

    p1_t1 = p1.tasks.first

    sub1 = grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]

    other_grp.add_member p1

    p1_t1.reload

    expect(p1_t1.group).not_to eq(grp)
    expect(p1_t1.group).to eq(other_grp)
  end


  it "should ensure that group submissions have all group members" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1, student_count: 4, :groups => [ { gs: 0, students: 2}, { gs: 0, students: 2} ], :group_tasks => [ { gs: 0, idx: 0 } ])

    grp = unit.group_sets[0].groups.first

    p1 = grp.projects.first
    p1_t1 = p1.tasks.first

    expect { grp.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 100} ] }.to raise_error "Contributions missing for some group members"
  end

  it "should delete old group submissions, when new group submits work" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 1,
      student_count: 3,
      :groups => [ { gs: 0, students: 2}, {gs: 0, students: 1} ],
      :group_tasks => [ { gs: 0, idx: 0 } ]
    )

    grp0 = unit.group_sets[0].groups[0]
    grp1 = unit.group_sets[0].groups[1]

    p1 = grp0.projects[0]
    p2 = grp0.projects[1]
    p3 = grp1.projects[0]

    p1_t1 = p1.tasks.first

    sub1 = grp0.create_submission p1_t1, "Group has submitted its awesome work", [ { project: p1, pct: 50}, { project: p2, pct: 50} ]

    orig_id = sub1.id

    grp0.remove_member p2
    grp1.add_member p2

    # ensure it is reloaded
    sub2 = grp0.create_submission p1_t1, "New group submission", [ { project: p1, pct: 100 } ]

    grp1.reload
    # puts "group 1 = #{grp1.projects.include? p2} #{grp1.projects.include? p3} #{grp1.projects.include? p1}"
    sub3 = grp1.create_submission p2.tasks.first, "Next group submission", [ { project: p2, pct: 50 }, { project: p3, pct: 50} ]

    expect( GroupSubmission.where(id: orig_id).first ).to be nil
  end

  it "should allow comments to be viewed across all related tasks" do
    unit = FactoryBot.create(:unit, group_sets: 1, task_count: 2,
      student_count: 3,
      :groups => [ { gs: 0, students: 2}, {gs: 0, students: 1} ],
      :group_tasks => [ { gs: 0, idx: 0 } ]
    )

    grp0 = unit.group_sets[0].groups[0]

    t0 = grp0.projects[0].task_for_task_definition(unit.task_definitions[0])
    t1 = grp0.projects[0].task_for_task_definition(unit.task_definitions[1])

    comment = t0.add_text_comment t0.student, "Comment 1"
    comment1 = t1.add_text_comment t1.student, "Comment 2"

    t0.reload
    t1.reload

    expect(t0.all_comments).to include(comment)
    expect(t1.all_comments).to include(comment1)

    expect(grp0.projects[1].matching_task(t0).all_comments).to include(comment)
    expect(grp0.projects[1].matching_task(t1).all_comments).not_to include(comment1)
  end

  it "should ensure that names are unique within a groupset" do
    gs = FactoryBot.create(:group_set)
    g = FactoryBot.create(:group, group_set: gs, name: "G1")
    expect {g2 = FactoryBot.create(:group, group_set: gs, name: "G1")}.to raise_exception ActiveRecord::RecordInvalid
    g2 = FactoryBot.create(:group, group_set: gs, name: "G2")
    g2.name = "G1"
    expect {g2.save!}.to raise_exception ActiveRecord::RecordInvalid
  end

  it "should ensure that projects are restricted to the same tutorial as the group -- if required" do
    unit = FactoryBot.create(:unit, tutorials:2, student_count:4)
    gs = FactoryBot.create(:group_set, unit: unit)
    t0_g1 = FactoryBot.create(:group, group_set: gs, name: "G1 T0", tutorial:unit.tutorials[0])
    t1_g1 = FactoryBot.create(:group, group_set: gs, name: "G1 T1", tutorial:unit.tutorials[1])

    t0_p0 = unit.tutorials[0].projects[0]
    t0_p1 = unit.tutorials[0].projects[1]

    t1_p0 = unit.tutorials[1].projects[0]
    t1_p1 = unit.tutorials[1].projects[1]

    gs.keep_groups_in_same_class = true
    gs.save

    t0_g1.add_member(t0_p0)
    expect { t0_g1.add_member(t1_p0) }.to raise_exception ActiveRecord::RecordInvalid

    gs.keep_groups_in_same_class = false
    gs.save
    t0_g1.add_member(t1_p0)

    gs.reload
    gs.keep_groups_in_same_class = true
    expect { gs.save! }.to raise_exception ActiveRecord::RecordInvalid
  end

end
