require "test_helper"

class GroupModelTest < ActiveSupport::TestCase

  def test_add_group_members
    project = FactoryBot.create(:project)
    group1 = FactoryBot.create(:group)
    assert group1.valid?

    group1.add_member project

    assert_includes(group1.projects,project)
    assert_equal group1.group_memberships.count, 1
  end

  def test_hides_inactive_members
    project = FactoryBot.create(:project)
    group1 = FactoryBot.create(:group)
    #test group created correctly
    assert group1.valid?

    group1.add_member project
    group1.remove_member project
    #test project removed correctly
    refute_includes(group1.projects,project)
  end

  def test_allow_student_to_rejoin
    project = FactoryBot.create(:project)
    group1 = FactoryBot.create(:group)
    #test group created correctly
    assert group1.valid?

    group1.add_member project
    group1.remove_member project
    group1.add_member project

    assert_includes(group1.projects,project)
    assert_equal group1.group_memberships.count, 1
  end

  def test_knows_past_members
    project1 = FactoryBot.create(:project)
    project2 = FactoryBot.create(:project, unit: project1.unit)
    group1 = FactoryBot.create(:group, unit: project1.unit)

    group1.add_member project1
    group1.add_member project2
    group1.remove_member project1
    
    refute_includes(group1.projects,project1)
    assert_includes(group1.past_projects,project1)
    assert_includes(group1.projects,project2)
    refute_includes(group1.past_projects,project2)
    assert_equal group1.group_memberships.count, 2
  end

  def test_capacity_ranges
    gs = FactoryBot.create :group_set

    gs.capacity = 2
    assert gs.valid?
    gs.capacity = 1
    refute gs.valid?
    gs.capacity = 0
    refute gs.valid?
  end

  def test_at_capacity
    unit = FactoryBot.create :unit, group_sets: 1, groups: [{gs: 0, students: 2}]
    gs = unit.group_sets.first
    group1 = gs.groups.first
    assert group1.valid?

    refute group1.at_capacity?

    gs.update(capacity: 2)

    assert group1.at_capacity?

    project = FactoryBot.create :project, unit: unit
    group1.add_member project

    assert group1.at_capacity?
    gs.update(capacity: 3)
    assert group1.at_capacity?
    gs.update(capacity: 4)
    refute group1.at_capacity?
    gs.update(capacity: nil)
    refute group1.at_capacity?
  end

  def test_switch_tutorial
    unit = FactoryBot.create :unit, group_sets: 1, groups: [{gs: 0, students: 0}]
    
    gs = unit.group_sets.first
    gs.update keep_groups_in_same_class: true, allow_students_to_manage_groups: true
    group1 = gs.groups.first

    p1 = group1.tutorial.projects.first
    p2 = group1.tutorial.projects.last

    group1.add_member p1
    group1.add_member p2

    tutorial = FactoryBot.create :tutorial, unit: unit, campus: nil
    
    refute p1.enrolled_in? tutorial
    refute p2.enrolled_in? tutorial
    
    group1.switch_to_tutorial tutorial
    
    assert p1.enrolled_in? tutorial
    assert p2.enrolled_in? tutorial
  end

  def test_submit_with_others_having_extensions
    unit = FactoryBot.create :unit

    group_set = GroupSet.create!({name: 'test_group_submission_with_extensions', unit: unit})
    group_set.save!

    group = Group.create!({group_set: group_set, name: 'test_group_submission_with_extensions', tutorial: unit.tutorials.first})

    group.add_member(unit.active_projects[0])
    group.add_member(unit.active_projects[1])
    group.add_member(unit.active_projects[2])

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task for test',
        description: 'test def',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now + 3.days,
        target_date: Time.zone.now + 1.week,
        due_date: Time.zone.now + 3.weeks,
        abbreviation: 'GrpSubm',
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        group_set: group_set
      })
    assert td.save!

    p1 = group.projects.first
    tutor = p1.tutor_for(td)

    p2 = group.projects.second
    p3 = group.projects.last
    
    t1 = p1.task_for_task_definition(td)
    t2 = p2.task_for_task_definition(td)
    t3 = p3.task_for_task_definition(td)

    duration = t1.weeks_can_extend

    t1.apply_for_extension(p1.student, "Test comment", duration)
    t1.reload

    assert_equal 1, t1.comments.count
    assert_equal 0, t2.comments.count, t2.comments.map {|c| c.comment }
    assert_equal duration, t1.extensions

    assert_equal 0, t2.extensions

    t2.create_submission_and_trigger_state_change(t2.student, true, nil, 'ready_to_mark')

    t2.reload
    t1.reload
    t3.reload

    assert t2.valid?
    assert_equal 2, t1.extensions
    assert_equal 0, t2.extensions
    assert_equal :ready_to_mark, t1.status
    assert_equal :ready_to_mark, t2.status
    assert_equal 1, t1.comments.count, t1.comments.map {|c| c.comment }
    assert_equal 1, t2.comments.count, t2.comments.map {|c| c.comment }
    assert_equal 0, t3.comments.count, t3.comments.map {|c| c.comment }

    t2.trigger_transition trigger: 'complete', by_user: tutor

    t2.reload
    t1.reload
    t3.reload

    puts t3.comments.map {|c| c.comment }

    assert t2.valid?
    assert_equal :complete, t1.status
    assert_equal :complete, t2.status
    assert_equal 2, t1.extensions
    assert_equal 0, t2.extensions
    assert_equal 1, t1.comments.count
    assert_equal 2, t2.comments.count
    assert_equal 0, t3.comments.count, t3.comments.map {|c| c.comment }

    unit.destroy
  end
end
