require "test_helper"

class ProjectModelTest < ActiveSupport::TestCase
  include TestHelpers::TestFileHelper

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

  def test_matching_tasks
    unit = FactoryBot.create(:unit, student_count:2)
    campus = Campus.first

    p1 = unit.students[0]
    p2 = unit.students[1]

    t2 = p2.task_for_task_definition unit.task_definitions.first
    t1 = p1.matching_task t2

    assert_equal t1.task_definition, t2.task_definition
  end

  def test_create_empty_portfolio
    project = FactoryBot.create(:project)
    unit = project.unit

    project.update compile_portfolio: true
    assert project.compile_portfolio

    project.create_portfolio
    refute project.reload.compile_portfolio
    assert project.portfolio_exists?
    assert File.exist?(project.portfolio_path)

    unit.destroy!
  end

  def test_create_portfolio_with_lsr
    project = FactoryBot.create(:project)
    unit = project.unit

    project.update compile_portfolio: true
    assert project.compile_portfolio

    project.move_to_portfolio( {
      filename: "LearningSummaryReport.pdf",
      'tempfile' => File.new(test_file_path("submissions/1.2P.pdf"))
    }, "LearningSummaryReport", "document")

    project.create_portfolio
    refute project.reload.compile_portfolio
    assert project.portfolio_exists?
    assert File.exist?(project.portfolio_path)

    unit.destroy!
  end

  def test_create_portfolio_with_additional_files
    project = FactoryBot.create(:project)
    unit = project.unit

    project.update compile_portfolio: true
    assert project.compile_portfolio

    project.move_to_portfolio( {
      filename: "LearningSummaryReport.pdf",
      'tempfile' => File.new(test_file_path("submissions/1.2P.pdf"))
    }, "LearningSummaryReport", "document")

    project.move_to_portfolio( {
      filename: "1.2P.pdf",
      'tempfile' => File.new(test_file_path("submissions/1.2P.pdf"))
    }, "1.2P.pdf", "document")

    project.move_to_portfolio( {
      filename: "logo.jpeg",
      'tempfile' => File.new(test_file_path("submissions/Deakin_Logo.jpeg"))
    }, "logo.jpeg", "image")

    project.move_to_portfolio( {
      filename: "program.cs",
      'tempfile' => File.new(test_file_path("submissions/program.cs"))
    }, "program.cs", "code")

    project.move_to_portfolio( {
      filename: "vectorial_graph.ipynb",
      'tempfile' => File.new(test_file_path("submissions/vectorial_graph.ipynb"))
    }, "vectorial_graph.ipynb", "code")

    project.create_portfolio
    refute project.reload.compile_portfolio
    assert project.portfolio_exists?

    assert File.exist?(project.portfolio_path)

    unit.destroy!
  end


end
