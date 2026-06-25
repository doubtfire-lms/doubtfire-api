# frozen_string_literal: true

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

  def test_portfolio_tasks_excludes_tasks_until_pdf_processing_finishes
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    project = FactoryBot.create(:project, unit: unit)
    no_upload_task_definition = FactoryBot.create(:task_definition, unit: unit, upload_requirements: [])
    finished_task_definition = FactoryBot.create(:task_definition, unit: unit)
    processing_task_definition = FactoryBot.create(:task_definition, unit: unit)

    no_upload_task = FactoryBot.create(
      :task,
      project: project,
      task_definition: no_upload_task_definition,
      task_status: TaskStatus.ready_for_feedback
    )
    finished_task = FactoryBot.create(
      :task,
      project: project,
      task_definition: finished_task_definition,
      task_status: TaskStatus.ready_for_feedback
    )
    processing_task = FactoryBot.create(
      :task,
      project: project,
      task_definition: processing_task_definition,
      task_status: TaskStatus.ready_for_feedback
    )

    FileUtils.touch(finished_task.final_pdf_path)
    FileUtils.touch(processing_task.final_pdf_path)
    processing_dir = FileHelper.student_work_dir(:new, processing_task, true)

    assert_includes project.portfolio_tasks, no_upload_task
    assert_includes project.portfolio_tasks, finished_task
    assert_not_includes project.portfolio_tasks, processing_task
    assert_includes project.tasks_processing_pdf, processing_task

    FileUtils.rm_r(processing_dir)

    assert_includes project.portfolio_tasks, processing_task
    assert_not_includes project.tasks_processing_pdf, processing_task

    unit.destroy!
  end

  def test_create_portfolio_with_lsr
    project = FactoryBot.create(:project)
    unit = project.unit

    project.update compile_portfolio: true
    assert project.compile_portfolio

    project.move_to_portfolio(
      {
        filename: 'LearningSummaryReport.pdf',
        'tempfile' => File.new(test_file_path("submissions/1.2P.pdf"))
      }, "LearningSummaryReport", "document"
    )

    project.create_portfolio
    assert_not project.reload.compile_portfolio
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

  def test_can_update_spec_con_days
    project = FactoryBot.create(:project)
    assert_equal 0, project.spec_con_days

    project.update(spec_con_days: 5)
    assert_equal 5, project.reload.spec_con_days

    project.spec_con_days = nil
    assert_not project.valid?
    assert_equal 5, project.reload.spec_con_days
  end

  def test_spec_con_adjusts_task_deadlines
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    task_definition = FactoryBot.create(:task_definition, unit: unit, target_date: 1.week.from_now, due_date: 2.weeks.from_now)
    project = FactoryBot.create(:project, unit: unit)
    task = project.task_for_task_definition(task_definition)

    # Adjust deadlines based on spec con days
    project.update(spec_con_days: 2)

    # add extensions - to take up the spec con days
    task.extensions = 2

    # Check that the deadline has been extended by the spec con days
    assert_equal task_definition.reload.due_date.to_date + 2.days, task.due_date
  end

  def test_spec_con_reverts_overdue_tasks
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    unit.update!(allow_flexible_dates: true)

    task_definition1 = FactoryBot.create(:task_definition, unit: unit, target_date: Time.zone.today - 1.week, due_date: Time.zone.today - 1.day)
    task_definition2 = FactoryBot.create(:task_definition, unit: unit, target_date: Time.zone.today - 1.week, due_date: Time.zone.today - 4.days)
    project = FactoryBot.create(:project, unit: unit)
    task1 = project.task_for_task_definition(task_definition1)
    task2 = project.task_for_task_definition(task_definition2)

    task1.update!(submission_date: Time.zone.now, task_status: TaskStatus.time_exceeded)
    task2.update!(submission_date: Time.zone.now, task_status: TaskStatus.assess_in_portfolio)

    project.update!(spec_con_days: 2)

    task1.reload
    task2.reload

    assert_equal TaskStatus.ready_for_feedback, task1.task_status
    assert_equal TaskStatus.assess_in_portfolio, task2.task_status

    project.update!(spec_con_days: 4)

    task1.reload
    task2.reload

    assert_equal TaskStatus.ready_for_feedback, task1.task_status
    assert_equal TaskStatus.ready_for_feedback, task2.task_status
  end

  def test_unique_project_on_unit_and_user
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    student1 = FactoryBot.create(:user, :student)
    student2 = FactoryBot.create(:user, :student)

    # Create project for student1
    project1 = FactoryBot.create(:project, unit: unit, user: student1)
    assert project1.valid?

    # Create project for student2
    project2 = FactoryBot.build(:project, unit: unit, user: student2)
    assert project2.valid?

    # Attempt to create duplicate project for student1
    project3 = FactoryBot.build(:project, unit: unit, user: student1)
    assert_not project3.valid?
    assert_includes project3.errors[:user_id], "has already been taken"
  end
end
