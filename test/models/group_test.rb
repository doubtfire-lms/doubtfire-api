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
end
