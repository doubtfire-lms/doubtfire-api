require 'test_helper'

class TaskStatusTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_ensure_status_matches_id
    TaskStatus.all.each do |ts|
      assert_equal TaskStatus.id_to_key(ts.id), ts.status_key
    end
  end

  def test_status_chanaged_with_extenssion
    unit = FactoryBot.create :unit
    td = TaskDefinition.new({
                              unit_id: unit.id,
                              name: 'Task past due - for revert',
                              description: 'Task past due',
                              weighting: 4,
                              target_grade: 0,
                              start_date: Time.zone.now - 2.weeks,
                              target_date: Time.zone.now - 1.week,
                              due_date: Time.zone.now + 1.week,
                              abbreviation: 'TaskPastDueForRevert',
                              restrict_status_updates: false,
                              upload_requirements: [],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0,
                              tutorial_stream_id: nil,
                              assess_in_portfolio_only: false
                            })
    td.save!

    # Get the first student - who now has this task
    project = unit.active_projects.first

    # create a time exceeded task
    tc = Task.create!(
      project_id: project.id,
      task_definition_id: td.id,
      task_status: TaskStatus.time_exceeded
    )

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    add_auth_header_for(user: project.student)

    # Make a submission for this student
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    tc.reload

    # Get the exceeded exceeded task and check it is now time exceeded
    # task = project.task_for_task_definition(td)
    assert_equal TaskStatus.time_exceeded, tc.task_status
  end

  def test_status_changed_task_definition_assess_in_portfolio_only
    unit = FactoryBot.create :unit
    td = TaskDefinition.new({
                              unit_id: unit.id,
                              name: 'Task past due - for revert',
                              description: 'Task past due',
                              weighting: 4,
                              target_grade: 0,
                              start_date: Time.zone.now - 2.weeks,
                              target_date: Time.zone.now - 1.week,
                              due_date: Time.zone.now + 1.week,
                              abbreviation: 'TaskPastDueForRevert',
                              restrict_status_updates: false,
                              upload_requirements: [],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0,
                              tutorial_stream_id: nil,
                              assess_in_portfolio_only: true
                            })
    td.save!

    # Get the first student - who now has this task
    project = unit.active_projects.first

    # create a time exceeded task
    tc = Task.create!(
      project_id: project.id,
      task_definition_id: td.id,
      task_status: TaskStatus.not_started
    )

    data_to_post = {
      trigger: 'ready_for_feedback',
      comment: "I would like feedback for my task"
    }

    add_auth_header_for(user: project.student)

    # Make a submission for this student
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    # Get the exceeded exceeded task and check it is now assess_in_portfolio
    tc.reload
    assert_equal TaskStatus.assess_in_portfolio, tc.task_status
  end

  def test_status_changed_unit_has_assess_in_portfolio_tasks
    unit = FactoryBot.create :unit
    unit.update(mark_late_submissions_as_assess_in_portfolio: true)

    td = TaskDefinition.new({
                              unit_id: unit.id,
                              name: 'Task past due - for revert',
                              description: 'Task past due',
                              weighting: 4,
                              target_grade: 0,
                              start_date: Time.zone.now - 2.weeks,
                              target_date: Time.zone.now - 1.week,
                              due_date: Time.zone.now + 1.week,
                              abbreviation: 'TaskPastDueForRevert',
                              restrict_status_updates: false,
                              upload_requirements: [],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0,
                              tutorial_stream_id: nil,
                              assess_in_portfolio_only: false # Task should still switch to assess in portfolio if unit has it enabled
                            })
    td.save!

    # Get the first student - who now has this task
    project = unit.active_projects.first

    # create a time exceeded task
    tc = Task.create!(
      project_id: project.id,
      task_definition_id: td.id,
      task_status: TaskStatus.not_started
    )

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    add_auth_header_for(user: project.student)

    # Make a submission for this student
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    tc.reload
    assert_equal TaskStatus.assess_in_portfolio, tc.task_status
  end

  def test_tutor_cant_signoff_tasks_complete_assess_in_portfolio_only
    unit = FactoryBot.create :unit
    unit.update(mark_late_submissions_as_assess_in_portfolio: true)

    td = TaskDefinition.new({
                              unit_id: unit.id,
                              name: 'Task past due - for revert',
                              description: 'Task past due',
                              weighting: 4,
                              target_grade: 0,
                              start_date: Time.zone.now - 2.weeks,
                              target_date: Time.zone.now + 1.week,
                              due_date: Time.zone.now + 1.week,
                              abbreviation: 'TaskPastDueForRevert',
                              restrict_status_updates: false,
                              upload_requirements: [],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0,
                              tutorial_stream_id: nil,
                              assess_in_portfolio_only: true
                            })
    td.save!

    # Get the first student - who now has this task
    project = unit.active_projects.first

    # create a not started task
    tc = Task.create!(
      project_id: project.id,
      task_definition_id: td.id,
      task_status: TaskStatus.not_started
    )

    data_to_post = {
      trigger: 'ready_for_feedback',
      comment: 'I would like feedback for my task'
    }

    add_auth_header_for(user: project.student)

    # Make a submission for this student
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    tc.reload

    assert_equal TaskStatus.ready_for_feedback, tc.task_status

    tutor = unit.tutors.first
    add_auth_header_for(user: tutor)

    data_to_post = {
      trigger: 'complete'
    }

    put "/api/projects/#{project.id}/task_def_id/#{td.id}", data_to_post

    tc.reload
    assert_not_equal TaskStatus.complete, tc.task_status
    # Task status should not have changed
    assert_equal TaskStatus.ready_for_feedback, tc.task_status
  end

  def test_tutor_can_update_assess_in_portfolio_tasks_to_working_on_it
    unit = FactoryBot.create :unit
    unit.update(mark_late_submissions_as_assess_in_portfolio: true)

    td = TaskDefinition.new({
                              unit_id: unit.id,
                              name: 'Task past due - for revert',
                              description: 'Task past due',
                              weighting: 4,
                              target_grade: 0,
                              start_date: Time.zone.now - 2.weeks,
                              target_date: Time.zone.now + 1.week,
                              due_date: Time.zone.now + 1.week,
                              abbreviation: 'TaskPastDueForRevert',
                              restrict_status_updates: false,
                              upload_requirements: [],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0,
                              tutorial_stream_id: nil,
                              assess_in_portfolio_only: true
                            })
    td.save!

    # Get the first student - who now has this task
    project = unit.active_projects.first

    # create a task ready for feedback
    tc = Task.create!(
      project_id: project.id,
      task_definition_id: td.id,
      task_status: TaskStatus.ready_for_feedback
    )

    tutor = unit.tutors.first
    add_auth_header_for(user: tutor)

    data_to_post = {
      trigger: 'working_on_it'
    }

    put "/api/projects/#{project.id}/task_def_id/#{td.id}", data_to_post

    tc.reload
    # Ensure tutors can set it to working_on_it state
    assert_equal TaskStatus.working_on_it, tc.task_status
  end

  def test_student_cant_update_assess_in_portfolio_without_files
    unit = FactoryBot.create :unit
    unit.update(mark_late_submissions_as_assess_in_portfolio: true)

    td = TaskDefinition.new({
                              unit_id: unit.id,
                              name: 'Task past due - for revert',
                              description: 'Task past due',
                              weighting: 4,
                              target_grade: 0,
                              start_date: Time.zone.now - 2.weeks,
                              target_date: Time.zone.now + 1.week,
                              due_date: Time.zone.now + 1.week,
                              abbreviation: 'TaskPastDueForRevert',
                              restrict_status_updates: false,
                              upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0,
                              tutorial_stream_id: nil,
                              assess_in_portfolio_only: true
                            })
    td.save!

    # Get the first student - who now has this task
    project = unit.active_projects.first

    # create a task not_started
    tc = Task.create!(
      project_id: project.id,
      task_definition_id: td.id,
      task_status: TaskStatus.not_started
    )

    add_auth_header_for(user: project.student)

    data_to_post = {
      trigger: 'assess_in_portfolio'
    }

    put "/api/projects/#{project.id}/task_def_id/#{td.id}", data_to_post

    tc.reload
    # Ensure students cant change status without uploading evidence
    assert_equal TaskStatus.not_started, tc.task_status

    tutor = unit.tutors.first
    add_auth_header_for(user: tutor)

    data_to_post = {
      trigger: 'assess_in_portfolio'
    }

    put "/api/projects/#{project.id}/task_def_id/#{td.id}", data_to_post

    tc.reload
    # Tutors should be able to update status to assess_in_portfolio without file upload
    assert_equal TaskStatus.assess_in_portfolio, tc.task_status
  end

  def test_student_cant_update_assess_in_portfolio_if_task_def_not_aip
    unit = FactoryBot.create :unit
    unit.update(mark_late_submissions_as_assess_in_portfolio: true)

    td = TaskDefinition.new({
                              unit_id: unit.id,
                              name: 'Task past due - for revert',
                              description: 'Task past due',
                              weighting: 4,
                              target_grade: 0,
                              start_date: Time.zone.now - 2.weeks,
                              target_date: Time.zone.now + 1.week,
                              due_date: Time.zone.now + 1.week,
                              abbreviation: 'TaskPastDueForRevert',
                              restrict_status_updates: false,
                              upload_requirements: [],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0,
                              tutorial_stream_id: nil,
                              assess_in_portfolio_only: false
                            })
    td.save!

    # Get the first student - who now has this task
    project = unit.active_projects.first

    # create a task not_started
    tc = Task.create!(
      project_id: project.id,
      task_definition_id: td.id,
      task_status: TaskStatus.not_started
    )

    add_auth_header_for(user: project.student)

    data_to_post = {
      trigger: 'assess_in_portfolio'
    }

    put "/api/projects/#{project.id}/task_def_id/#{td.id}", data_to_post

    tc.reload
    # Ensure students can't change status to assess_in_portfolio if taskdef.assess_in_portfolio_only = false
    assert_equal TaskStatus.not_started, tc.task_status

    tutor = unit.tutors.first
    add_auth_header_for(user: tutor)

    data_to_post = {
      trigger: 'assess_in_portfolio'
    }

    put "/api/projects/#{project.id}/task_def_id/#{td.id}", data_to_post

    tc.reload
    # Tutors should still be able to update status to assess_in_portfolio if assess_in_portfolio_only = false
    assert_equal TaskStatus.assess_in_portfolio, tc.task_status
  end

  def test_submission_for_assess_in_portfolio
    unit = Unit.first
    td = TaskDefinition.new({
                              unit_id: unit.id,
                              tutorial_stream: unit.tutorial_streams.first,
                              name: 'Task with image2',
                              description: 'img task2',
                              weighting: 4,
                              target_grade: 0,
                              start_date: unit.start_date + 1.week,
                              target_date: unit.start_date + 2.weeks,
                              abbreviation: 'TaskPdfWithGif2',
                              restrict_status_updates: false,
                              upload_requirements: [{ "key" => 'file0', "name" => 'An Image', "type" => 'image' }],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0,
                              assess_in_portfolio_only: true
                            })
    td.save!

    data_to_post = {
      trigger: 'assess_in_portfolio'
    }

    data_to_post = with_file('test_files/submissions/unbelievable.gif', 'image/gif', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: project.student
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)

    task.reload
    assert_equal TaskStatus.assess_in_portfolio, task.task_status

    td.destroy
  end

  def test_assess_in_portfolio_submissions_dont_show_in_tutor_inbox
    unit = Unit.first
    td = TaskDefinition.new({
                              unit_id: unit.id,
                              tutorial_stream: unit.tutorial_streams.first,
                              name: 'Task with image2',
                              description: 'img task2',
                              weighting: 4,
                              target_grade: 0,
                              start_date: unit.start_date + 1.week,
                              target_date: unit.start_date + 2.weeks,
                              abbreviation: 'TaskPdfWithGif2',
                              restrict_status_updates: false,
                              upload_requirements: [{ "key" => 'file0', "name" => 'An Image', "type" => 'image' }],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0,
                              assess_in_portfolio_only: true
                            })
    td.save!

    project = unit.active_projects.first
    tutor = unit.tutors.first

    Task.create!(
      project_id: project.id,
      task_definition_id: td.id,
      task_status: TaskStatus.assess_in_portfolio
    )

    inbox = unit.tasks_for_task_inbox(tutor)

    assert_not(inbox.any? { |task| task.status_id == TaskStatus.assess_in_portfolio.id }, "Task should not be in inbox")

    td.destroy
  end

  def test_status_for_name
    assert_equal TaskStatus.status_for_name('complete').name, TaskStatus.complete.name
    assert_equal TaskStatus.status_for_name('fix_and_resubmit').name, TaskStatus.fix_and_resubmit.name
    assert_equal TaskStatus.status_for_name('fix and resubmit').name, TaskStatus.fix_and_resubmit.name
    assert_equal TaskStatus.status_for_name('fix').name, TaskStatus.fix_and_resubmit.name
    assert_raise NoMethodError do
      assert_equal TaskStatus.status_for_name('f').name, TaskStatus.fix.name
    end

    assert_equal TaskStatus.status_for_name('do_not_resubmit').name, TaskStatus.feedback_exceeded.name
    assert_equal TaskStatus.status_for_name('do not resubmit').name, TaskStatus.feedback_exceeded.name
    assert_equal TaskStatus.status_for_name('feedback_exceeded').name, TaskStatus.feedback_exceeded.name
    assert_equal TaskStatus.status_for_name('feedback exceeded').name, TaskStatus.feedback_exceeded.name
    assert_equal TaskStatus.status_for_name('redo').name, TaskStatus.redo.name

    assert_equal TaskStatus.status_for_name('need_help').name, TaskStatus.need_help.name
    assert_equal TaskStatus.status_for_name('need help').name, TaskStatus.need_help.name
    assert_equal TaskStatus.status_for_name('working_on_it').name, TaskStatus.working_on_it.name
    assert_equal TaskStatus.status_for_name('working on it').name, TaskStatus.working_on_it.name
    assert_equal TaskStatus.status_for_name('discuss').name, TaskStatus.discuss.name
    assert_equal TaskStatus.status_for_name('d').name, TaskStatus.discuss.name

    assert_equal TaskStatus.status_for_name('demonstrate').name, TaskStatus.demonstrate.name
    assert_equal TaskStatus.status_for_name('demo').name, TaskStatus.demonstrate.name
    assert_equal TaskStatus.status_for_name('ready to mark').name, TaskStatus.ready_for_feedback.name
    assert_equal TaskStatus.status_for_name('ready_for_feedback').name, TaskStatus.ready_for_feedback.name
    assert_equal TaskStatus.status_for_name('rtm').name, TaskStatus.ready_for_feedback.name
    assert_equal TaskStatus.status_for_name('rff').name, TaskStatus.ready_for_feedback.name

    assert_equal TaskStatus.status_for_name('fail').name, TaskStatus.fail.name
    assert_equal TaskStatus.status_for_name('not_started').name, TaskStatus.not_started.name
    assert_equal TaskStatus.status_for_name('not started').name, TaskStatus.not_started.name
    assert_equal TaskStatus.status_for_name('ns').name, TaskStatus.not_started.name
    assert_equal TaskStatus.status_for_name('time exceeded').name, TaskStatus.time_exceeded.name
    assert_equal TaskStatus.status_for_name('time_exceeded').name, TaskStatus.time_exceeded.name

    assert_equal TaskStatus.status_for_name('aip').name, TaskStatus.assess_in_portfolio.name
    assert_equal TaskStatus.status_for_name('assess in portfolio').name, TaskStatus.assess_in_portfolio.name
    assert_equal TaskStatus.status_for_name('assess_in_portfolio').name, TaskStatus.assess_in_portfolio.name
    assert_nil TaskStatus.status_for_name('')
  end

  def test_staff_assigned_statuses
    assert_equal TaskStatus.staff_assigned_statuses.count, 10 # number of staff tasks
  end

  def test_id_to_key_not_started
    assert_equal TaskStatus.id_to_key(15), :not_started
  end

end
