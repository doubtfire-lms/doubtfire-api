require "test_helper"

class TutorialEnrolmentModelTest < ActiveSupport::TestCase
  def test_default_create
    tutorial_enrolment = FactoryBot.build(:tutorial_enrolment)
    assert tutorial_enrolment.valid?
    assert_equal tutorial_enrolment.project.unit, tutorial_enrolment.tutorial.unit
    assert_equal tutorial_enrolment.project.campus, tutorial_enrolment.tutorial.campus

    tutorial_enrolment = FactoryBot.create(:tutorial_enrolment)
    assert tutorial_enrolment.valid?
    assert_equal tutorial_enrolment.project.unit, tutorial_enrolment.tutorial.unit
    assert_equal tutorial_enrolment.project.campus, tutorial_enrolment.tutorial.campus
  end

  # Check that changing to a tutorial without a stream works as intended when there is a limited group
  def test_group_change_on_online_tutorial_switch
    # Create a unit with 2 streams, and a tutorial in each stream
    unit = FactoryBot.create(:unit, with_students: false, group_sets: 1, stream_count: 2, tutorials: 0)

    # Create the stream tutorials - factory will only create tutorials without streams
    t1 = Tutorial.create unit: unit, tutorial_stream: unit.tutorial_streams.first, abbreviation: 'T01'
    t2 = Tutorial.create unit: unit, tutorial_stream: unit.tutorial_streams.last, abbreviation: 'T02'
    t3 = Tutorial.create unit: unit, tutorial_stream: nil, abbreviation: 'T03'

    # Now make the group fixed, inflexible group
    grp_set = unit.group_sets.first
    grp_set.update(keep_groups_in_same_class: true, allow_students_to_manage_groups: false)

    # Make sure the first group is in a stream 1 tutorial
    grp = Group.create!({group_set: unit.group_sets.first, name: 'test-group', tutorial: t1})

    assert grp_set.keep_groups_in_same_class
    refute grp_set.allow_students_to_manage_groups
    assert grp.limit_members_to_tutorial?

    # Enrol a student - enrol in 2 tutorials to trigger destory of enrolments on cloud change
    # cloud change with 1 tutorial is the same as between tutorials in the same stream
    project = FactoryBot.create(:project, unit: unit)
    tutorial_enrolment = project.enrol_in(t1) # the group's tutorial
    other_enrolment = project.enrol_in(t2)

    # Now enrol in the group
    grp.add_member project

    # Now you cannot leave...
    assert_equal :leave_denied, tutorial_enrolment.action_on_student_leave_tutorial

    # So this should fail!
    assert_raises(ActiveRecord::RecordNotDestroyed, "Unable to change tutorial due to group enrolment in current tutorials.") { other_enrolment = project.enrol_in(t3) }

    # If we make this more flexible...
    grp_set.update(allow_students_to_manage_groups: true)

    # This should succeed
    other_enrolment = project.enrol_in(t3)

    # But they are no longer in the group
    refute grp.has_user(project.student)

    unit.destroy
  end

  # Check the actions that should occur on changing a tutorial
  def test_action_leave_tutorial
    # Create a unit with 2 streams, and a tutorial in each stream
    unit = FactoryBot.create(:unit, with_students: false, group_sets: 1, stream_count: 1, tutorials: 0)

    # Create the stream tutorials - factory will only create tutorials without streams
    t1 = Tutorial.create unit: unit, tutorial_stream: unit.tutorial_streams.first, abbreviation: 'T01'

    grp_set = unit.group_sets.first

    # Make sure the first group is in a stream 1 tutorial
    grp = Group.create!({group_set: unit.group_sets.first, name: 'test-change-streams', tutorial: t1})

    # Check this is currently a flexible group
    refute grp_set.keep_groups_in_same_class
    assert grp_set.allow_students_to_manage_groups
    refute grp.limit_members_to_tutorial?

    # Enrol a student
    project = FactoryBot.create(:project, unit: unit)
    tutorial_enrolment = project.enrol_in(t1)

    # Now enrol in the group
    grp.add_member project

    # This is a flexible group... so leaving has no effect
    assert_equal :none_can_leave, tutorial_enrolment.action_on_student_leave_tutorial

    # Now make the group fixed
    grp_set.update(keep_groups_in_same_class: true)
    grp.reload

    assert grp_set.keep_groups_in_same_class
    assert grp_set.allow_students_to_manage_groups
    assert grp.limit_members_to_tutorial?

    # Now you can leave if you remove from the group
    assert_equal :leave_after_remove_from_group, tutorial_enrolment.action_on_student_leave_tutorial

    # Now make the group more inflexible
    grp_set.update(allow_students_to_manage_groups: false)
    assert grp_set.keep_groups_in_same_class
    refute grp_set.allow_students_to_manage_groups
    assert grp.limit_members_to_tutorial?

    # Now you cannot leave...
    assert_equal :leave_denied, tutorial_enrolment.action_on_student_leave_tutorial

    grp.remove_member project
    assert_equal :none_can_leave, tutorial_enrolment.action_on_student_leave_tutorial

    unit.destroy
  end

  # Check that changing tutorials in other streams does not break group enrolment in other streams
  def test_change_tutorial_does_not_break_group_in_other_stream
    # Create a unit with 2 streams, and a tutorial in each stream
    unit = FactoryBot.create(:unit, with_students: false, group_sets: 1, stream_count: 3, tutorials: 0)

    # Create the stream tutorials - factory will only create tutorials without streams
    t1 = Tutorial.create unit: unit, tutorial_stream: unit.tutorial_streams.second, abbreviation: 'T01'
    t2 = Tutorial.create unit: unit, tutorial_stream: unit.tutorial_streams.first, abbreviation: 'T02'
    t3 = Tutorial.create unit: unit, tutorial_stream: unit.tutorial_streams.second, abbreviation: 'T03'
    t4 = Tutorial.create unit: unit, tutorial_stream: unit.tutorial_streams.first, abbreviation: 'T04'
    t5 = Tutorial.create unit: unit, tutorial_stream: unit.tutorial_streams.last, abbreviation: 'T05'
    t6 = Tutorial.create unit: unit, tutorial_stream: unit.tutorial_streams.last, abbreviation: 'T06'

    unit.group_sets.first.update(keep_groups_in_same_class: true)

    assert unit.group_sets.first.keep_groups_in_same_class

    # Make sure the first group is in a stream 1 tutorial
    grp = Group.create!({group_set: unit.group_sets.first, name: 'test-change-streams', tutorial: t1})
    assert grp.limit_members_to_tutorial?

    # Enrol a student
    project = FactoryBot.create(:project, unit: unit)
    tutorial_enrolment = project.enrol_in(t1)

    # Make sure this has all worked
    assert_equal tutorial_enrolment.project, project
    assert_equal tutorial_enrolment.tutorial, t1
    assert tutorial_enrolment.valid?

    # Now enrol in the group
    grp.add_member project

    project.reload
    grp.reload

    # Ensure things are still valid
    assert grp.valid?
    assert_equal project.group_for_groupset(unit.group_sets.first), grp

    # Enrol in other tutorial and check still in group
    other_enrolment = project.enrol_in(t2)

    assert tutorial_enrolment.valid?
    assert other_enrolment.valid?
    assert_equal t2, other_enrolment.tutorial
    assert_equal grp, project.group_for_groupset(unit.group_sets.first)
    assert project.group_membership_for_groupset(unit.group_sets.first).active

    # Now change that enrolment...
    other_enrolment = project.enrol_in(t4)

    assert tutorial_enrolment.valid?
    assert other_enrolment.valid?
    assert_equal t4, other_enrolment.tutorial
    assert_equal grp, project.group_for_groupset(unit.group_sets.first)
    assert project.group_membership_for_groupset(unit.group_sets.first).active

    # Enrol in other tutorial and check still in group
    other_enrolment = project.enrol_in(t5)

    assert tutorial_enrolment.valid?
    assert other_enrolment.valid?
    assert_equal t5, other_enrolment.tutorial
    assert_equal grp, project.group_for_groupset(unit.group_sets.first)
    assert project.group_membership_for_groupset(unit.group_sets.first).active

    # Now change that enrolment...
    other_enrolment = project.enrol_in(t6)

    assert tutorial_enrolment.valid?
    assert other_enrolment.valid?
    assert_equal t6, other_enrolment.tutorial
    assert_equal grp, project.group_for_groupset(unit.group_sets.first)
    assert project.group_membership_for_groupset(unit.group_sets.first).active

    # Check that updating with no change does not remoe group membership
    updated_enrolment = project.enrol_in(t1)

    project.reload
    grp.reload

    assert_equal project.group_for_groupset(unit.group_sets.first), grp
    assert_equal updated_enrolment, tutorial_enrolment

    # Check that moving to another tutorial does remove from group
    updated_enrolment = project.enrol_in(t3)

    assert_nil project.group_for_groupset(unit.group_sets.first)
    assert updated_enrolment.valid?

    unit.destroy
  end

  def test_specific_create
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial = FactoryBot.create(:tutorial, unit: unit, campus: campus)
    tutorial_enrolment = FactoryBot.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial
    tutorial_enrolment.save!

    assert_equal tutorial_enrolment.project, project
    assert_equal tutorial_enrolment.tutorial, tutorial
    assert tutorial_enrolment.valid?
  end

  def test_project_plus_tutorial_is_unique
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial = FactoryBot.create(:tutorial, unit: unit, campus: campus)

    tutorial_enrolment = FactoryBot.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial
    tutorial_enrolment.save!

    tutorial_enrolment = FactoryBot.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial
    assert tutorial_enrolment.invalid?

    # Unique, multiple tutorials (with no stream) and max one validation will fail
    assert_equal 'Tutorial already exists for the selected student', tutorial_enrolment.errors.full_messages.first
    assert_equal 'Tutorial stream already exists for the selected student', tutorial_enrolment.errors.full_messages.second
    assert_equal 'Project cannot have more than one enrolment when it is enrolled in tutorial with no stream', tutorial_enrolment.errors.full_messages.third
  end

  def test_enrol_in_tutorial
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial = FactoryBot.create(:tutorial, unit: unit, campus: campus)
    tutorial_enrolment = project.enrol_in(tutorial)
    assert tutorial_enrolment.valid?
    assert_equal tutorial_enrolment.project, project
    assert_equal tutorial_enrolment.tutorial, tutorial
  end

  def test_enrolling_twice_in_same_tutorial_stream_updates_enrolment
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_first = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    tutorial_second = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)

    # Confirm that both tutorials have same tutorial stream
    assert_equal tutorial_stream, tutorial_first.tutorial_stream
    assert_equal tutorial_stream, tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial
    assert_equal project, tutorial_enrolment_first.project

    # Enrol again in tutorial stream and check that it updates the tutorial enrolment rather than creating a new one
    tutorial_enrolment_second = project.enrol_in(tutorial_second)
    assert_equal tutorial_second, tutorial_enrolment_second.tutorial
    assert_equal tutorial_enrolment_first.id, tutorial_enrolment_second.id
  end

  def test_enrolling_twice_when_tutorial_stream_is_null
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = nil
    tutorial_first = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    tutorial_second = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    tutorial_third = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)

    # Confirm that tutorial stream is nil
    assert_nil tutorial_first.tutorial_stream
    assert_nil tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial
    assert_equal project, tutorial_enrolment_first.project

    # Enrol again in tutorial stream and check that it updates the tutorial enrolment rather than creating a new one
    tutorial_enrolment_second = project.enrol_in(tutorial_second)
    assert_equal tutorial_second, tutorial_enrolment_second.tutorial
    assert_equal tutorial_enrolment_first.id, tutorial_enrolment_second.id

    # Manually create a tutorial enrolment
    tutorial_enrolment_third = FactoryBot.build(:tutorial_enrolment, project: project)
    tutorial_enrolment_third.tutorial = tutorial_third
    assert tutorial_enrolment_third.invalid?
    assert_equal 'Project cannot have more than one enrolment when it is enrolled in tutorial with no stream', tutorial_enrolment_third.errors.full_messages.last
  end

  def test_creating_both_no_stream_and_stream
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    # Create tutorial with no tutorial stream
    tutorial_first = FactoryBot.create(:tutorial, unit: unit, campus: campus)
    assert_nil tutorial_first.tutorial_stream

    # Create tutorial with tutorial stream
    tutorial_stream = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_second = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    assert_not_nil tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial
    assert_equal 1, project.tutorial_enrolments.count

    tutorial_enrolment = FactoryBot.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial_second
    exception = assert_raises(Exception) { tutorial_enrolment.save! }
    assert_equal 'Validation failed: Project cannot have more than one enrolment when it is enrolled in tutorial with no stream', exception.message
  end

  def test_changing_from_no_stream_to_stream
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    # Create tutorial with no tutorial stream
    tutorial_first = FactoryBot.create(:tutorial, unit: unit, campus: campus)
    assert_nil tutorial_first.tutorial_stream

    # Create tutorial with tutorial stream
    tutorial_stream = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_second = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    assert_not_nil tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial

    # Enrol same project in tutorial second
    tutorial_enrolment_second = project.enrol_in(tutorial_second)
    assert_equal tutorial_second, tutorial_enrolment_second.tutorial

    # Updates rather than creating a new instance
    assert_equal tutorial_enrolment_first.id, tutorial_enrolment_second.id
  end

  def test_changing_from_stream_to_no_stream
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    # Create tutorial with tutorial stream
    tutorial_stream = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_first = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    assert_not_nil tutorial_first.tutorial_stream

    # Create tutorial with no tutorial stream
    tutorial_second = FactoryBot.create(:tutorial, unit: unit, campus: campus)
    assert_nil tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial

    # Enrol same project in tutorial second - will switch enrolment
    assert_equal tutorial_enrolment_first, project.matching_enrolment(tutorial_first)

    tutorial_enrolment_second = project.enrol_in(tutorial_second)
    assert_equal 1, project.tutorial_enrolments.count
    assert_equal tutorial_second, tutorial_enrolment_second.tutorial
  end

  def test_cannot_enrol_in_tutorial_stream_twice
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_first = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)
    tutorial_second = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: campus)

    # Confirm that both tutorials have same tutorial stream
    assert_equal tutorial_stream, tutorial_first.tutorial_stream
    assert_equal tutorial_stream, tutorial_second.tutorial_stream

    # Enrol project in tutorial first
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    assert_equal tutorial_first, tutorial_enrolment_first.tutorial
    assert_equal project, tutorial_enrolment_first.project

    # Create tutorial enrolment for the second tutorial
    tutorial_enrolment_second = FactoryBot.build(:tutorial_enrolment, project: project)
    tutorial_enrolment_second.tutorial = tutorial_second
    assert tutorial_enrolment_second.invalid?
    assert_equal 'Project already enrolled in a tutorial with same tutorial stream', tutorial_enrolment_second.errors.full_messages.last
  end

  def test_consistent_campus_is_allowed
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    # Create tutorial in the same campus
    tutorial = FactoryBot.create(:tutorial, unit: unit, campus: campus)

    # Make sure campus is same in project and tutorial
    assert_equal project.campus, tutorial.campus

    tutorial_enrolment = project.enrol_in(tutorial)
    assert tutorial_enrolment.valid?
    assert_equal project, tutorial_enrolment.project
    assert_equal tutorial, tutorial_enrolment.tutorial
  end

  def test_campus_inconsistency_raises_error
    unit = FactoryBot.create(:unit, with_students: false)
    campus_first = FactoryBot.create(:campus)
    campus_second = FactoryBot.create(:campus)
    project = FactoryBot.create(:project, unit: unit, campus: campus_first)

    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    # Create tutorial in a different campus
    tutorial = FactoryBot.create(:tutorial, unit: unit, campus: campus_second)

    # Make sure that campus is different in project and tutorial
    assert_not_equal project.campus, tutorial.campus

    tutorial_enrolment = FactoryBot.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial
    assert tutorial_enrolment.invalid?
    assert_equal 'Project and tutorial belong to different campus', tutorial_enrolment.errors.full_messages.last
  end

  def test_unit_inconsistency_raises_error
    campus = FactoryBot.create(:campus)
    unit_first = FactoryBot.create(:unit, with_students: false)
    unit_second = FactoryBot.create(:unit, with_students: false)

    project = FactoryBot.create(:project, unit: unit_first, campus: campus)
    tutorial = FactoryBot.create(:tutorial, unit: unit_second, campus: campus)

    # Make sure that project and tutorial have different units
    assert_not_equal project.unit, tutorial.unit

    tutorial_enrolment = FactoryBot.build(:tutorial_enrolment, project: project)
    tutorial_enrolment.tutorial = tutorial
    assert tutorial_enrolment.invalid?
    assert_equal 1, tutorial_enrolment.errors.full_messages.count
    assert_equal 'Project and tutorial belong to different unit', tutorial_enrolment.errors.full_messages.last
  end
end
