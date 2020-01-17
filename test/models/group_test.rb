require "test_helper"

class GroupModelTest < ActiveSupport::TestCase

  def test_add_group_members
    project = FactoryGirl.create(:project)
    group1 = FactoryGirl.create(:group)
    assert group1.valid?

    group1.add_member project

    assert_includes(group1.projects,project)
    assert_equal group1.group_memberships.count, 1
  end

  def test_hides_inactive_members
    project = FactoryGirl.create(:project)
    group1 = FactoryGirl.create(:group)
    #test group created correctly
    assert group1.valid?

    group1.add_member project
    group1.remove_member project
    #test project removed correctly
    refute_includes(group1.projects,project)
  end

  def test_allow_student_to_rejoin
    project = FactoryGirl.create(:project)
    group1 = FactoryGirl.create(:group)
    #test group created correctly
    assert group1.valid?

    group1.add_member project
    group1.remove_member project
    group1.add_member project

    assert_includes(group1.projects,project)
    assert_equal group1.group_memberships.count, 1
  end

  def test_knows_past_members
    project1 = FactoryGirl.create(:project)
    project2 = FactoryGirl.create(:project)
    group1 = FactoryGirl.create(:group)

    group1.add_member project1
    group1.add_member project2
    group1.remove_member project1
    
    refute_includes(group1.projects,project1)
    assert_includes(group1.past_projects,project1)
    assert_includes(group1.projects,project2)
    refute_includes(group1.past_projects,project2)
    assert_equal group1.group_memberships.count, 2
  end

  def test_exist_in_unit_factory
    unit = FactoryGirl.create(:unit, group_sets: 1, student_count: 2, :groups => [ { gs: 0, students: 2} ])
    assert unit.valid?
    assert_equal unit.group_sets[0].groups.count ,1
    assert_equal unit.group_sets[0].groups[0].projects.count ,2
  end

end
