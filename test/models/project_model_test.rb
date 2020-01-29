require "test_helper"

class ProjectModelTest < ActiveSupport::TestCase

  def test_tutor_for_task_def_when_tutorial_stream_is_present
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    tutorial_stream = FactoryBot.create(:tutorial_stream, unit: unit)
    task_definition = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    tutorial = FactoryBot.create(:tutorial, unit: unit, campus: campus, tutorial_stream: tutorial_stream, unit_role: unit.unit_roles.first)
    assert_equal tutorial_stream, tutorial.tutorial_stream
    assert_equal unit.unit_roles.first.user, tutorial.tutor

    tutorial_enrolment = project.enrol_in(tutorial)
    assert tutorial_enrolment.valid?

    tutor_for_task_def = project.tutor_for(task_definition)
    assert_equal tutorial.tutor, tutor_for_task_def
  end

  def test_tutor_for_task_def_when_tutorial_stream_is_null
    unit = FactoryBot.create(:unit, with_students: false)
    campus = FactoryBot.create(:campus)
    task_definition = FactoryBot.create(:task_definition, unit: unit)
    project = FactoryBot.create(:project, unit: unit, campus: campus)

    tutorial = FactoryBot.create(:tutorial, unit: unit, campus: campus, unit_role: unit.unit_roles.first)
    assert_nil tutorial.tutorial_stream
    assert_equal unit.unit_roles.first.user, tutorial.tutor

    tutorial_enrolment = project.enrol_in(tutorial)
    assert tutorial_enrolment.valid?

    tutor_for_task_def = project.tutor_for(task_definition)
    assert_equal tutorial.tutor, tutor_for_task_def
  end

  def test_tutor_for_task_def_for_match_all
    unit = FactoryBot.create(:unit, with_students: false, staff_count: 0)
    campus = FactoryBot.create(:campus)

    # Create different projects
    project_first = FactoryBot.create(:project, unit: unit, campus: campus)
    project_second = FactoryBot.create(:project, unit: unit, campus: campus)
    project_all = FactoryBot.create(:project, unit: unit, campus: campus)

    # Create all the tutorial streams in the unit
    tutorial_stream_first = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_stream_second = FactoryBot.create(:tutorial_stream, unit: unit)

    # Create all the task definitions, putting them in different tutorial streams
    task_definition_first = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_first)
    task_definition_second = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_second)

    # There is just one user initially
    assert_equal 1, unit.unit_roles.count

    # Employ two more staff
    unit.employ_staff( FactoryBot.create(:user, :convenor), Role.tutor)
    unit.employ_staff( FactoryBot.create(:user, :convenor), Role.tutor)
    assert_equal 3, unit.unit_roles.count

    tutorial_first = FactoryBot.create(:tutorial, unit: unit, campus: campus, tutorial_stream: tutorial_stream_first, unit_role: unit.unit_roles.first)
    assert_equal tutorial_stream_first, tutorial_first.tutorial_stream

    tutorial_second = FactoryBot.create(:tutorial, unit: unit, campus: campus, tutorial_stream: tutorial_stream_second, unit_role: unit.unit_roles.second)
    assert_equal tutorial_stream_second, tutorial_second.tutorial_stream

    tutorial_all = FactoryBot.create(:tutorial, unit: unit, campus: campus, unit_role: unit.unit_roles.third)
    assert_nil tutorial_all.tutorial_stream
    assert_equal unit.unit_roles.third.user, tutorial_all.tutor

    # Enrol project first in tutorial first
    tutorial_enrolment_first = project_first.enrol_in(tutorial_first)
    assert tutorial_enrolment_first.valid?

    # Enrol project second in tutorial second
    tutorial_enrolment_second = project_second.enrol_in(tutorial_second)
    assert tutorial_enrolment_second.valid?

    # Enrol project all in tutorial all
    tutorial_enrolment_all = project_all.enrol_in(tutorial_all)
    assert tutorial_enrolment_all.valid?

    # Get tutors for task definitions
    tutor_for_task_def_first = project_first.tutor_for(task_definition_first)
    tutor_for_task_def_second = project_second.tutor_for(task_definition_second)
    tutor_for_task_def_all_first = project_all.tutor_for(task_definition_first)
    tutor_for_task_def_all_second = project_all.tutor_for(task_definition_second)

    assert_equal tutorial_first.tutor, tutor_for_task_def_first
    assert_equal tutorial_second.tutor, tutor_for_task_def_second
    assert_equal tutorial_all.tutor, tutor_for_task_def_all_first
    assert_equal tutorial_all.tutor, tutor_for_task_def_all_second

    # Try to get tutor for task def for which given project is not enrolled
    tutor = project_first.tutor_for(task_definition_second)
    assert_equal project_first.main_convenor_user, tutor
  end

  def test_knows_past_groups
    project = Project.create
    group1 = FactoryBot.create(:group)
    group2 = FactoryBot.create(:group)

    group1.add_member project
    group2.add_member project
    group1.remove_member project

    assert_includes project.past_groups, group1
    refute_includes project.past_groups, group2
  end
  
end
