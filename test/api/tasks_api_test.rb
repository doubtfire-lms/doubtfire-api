require 'test_helper'

class TasksApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper
  include ActiveSupport::Testing::TimeHelpers

  def app
    Rails.application
  end

  def test_task_get
    # The GET we are testing
    unit = FactoryBot.create(:unit, perform_submissions: true)

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    get "/api/tasks?unit_id=#{unit.id}"
    expected_data = unit.student_tasks.where('task_status_id > ?', 1)

    assert_equal expected_data.count, last_response_body.count

    last_response_body.each_with_index do |r, _i|
      t = Task.find(r['id'])
      assert_json_matches_model t, r, %w[id task_definition_id]
      assert_equal t.status.to_s, r['status']
      tutorial = t.project.tutorial_for(t.task_definition)
      if tutorial.present?
        assert_equal tutorial.id, r['tutorial_id']
        if tutorial.tutorial_stream_id.nil?
          assert_nil r['tutorial_stream_id']
        else
          assert_equal tutorial.tutorial_stream_id, r['tutorial_stream_id']
        end
      else
        assert_nil r['tutorial_id']
        assert_nil r['tutorial_stream_id']
      end
    end
  end

  def test_get_task_submission_details_creates_session_and_activity
    # Start with a fresh unit and task definition
    unit = FactoryBot.create(:unit, auto_apply_extension_before_deadline: false)
    td = TaskDefinition.new({
                              unit_id: unit.id,
                              tutorial_stream: unit.tutorial_streams.first,
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
                              max_quality_pts: 0
                            })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    # Get the first student - who now has this task
    project = unit.active_projects.first

    # Track the counts before we make the request
    session_count_before = MarkingSession.count
    activity_count_before = SessionActivity.count

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # Make a submission for this student
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status

    # Make the request
    get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission_details"

    # Check if counts increased
    session_count_after = MarkingSession.count
    activity_count_after = SessionActivity.count

    # Assert that we created at least one new session and activity
    assert_operator session_count_after, :>, session_count_before, "No new sessions created"
    assert_operator activity_count_after, :>, activity_count_before, "No new activities created"

    # Get the most recent session and activity
    # Since we know they were just created
    session = MarkingSession.last
    activity = SessionActivity.last

    # Now test the associations
    assert_equal unit.id, session.unit_id
    assert_equal activity.marking_session_id, session.id
    assert_equal 'get-submission-details', activity.action

    # Clean up session activities first to avoid foreign key constraint issues
    SessionActivity.delete_all
    MarkingSession.delete_all
  end

  def test_task_get_with_streams
    # The GET we are testing
    unit = FactoryBot.create(:unit, perform_submissions: true, stream_count: 1, campus_count: 2)

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    get "/api/tasks?unit_id=#{unit.id}"
    expected_data = unit.student_tasks.where('task_status_id > ?', 1)

    assert_equal expected_data.count, last_response_body.count

    last_response_body.each_with_index do |r, _i|
      t = Task.find(r['id'])
      assert_json_matches_model t, r, %w[id task_definition_id]
      assert_equal t.status.to_s, r['status']
      tutorial = t.project.tutorial_for(t.task_definition)
      if tutorial.present?
        assert_equal tutorial.id, r['tutorial_id']
        if tutorial.tutorial_stream_id.nil?
          assert_nil r['tutorial_stream_id']
        else
          assert_equal tutorial.tutorial_stream_id, r['tutorial_stream_id']
        end
      else
        assert_nil r['tutorial_id']
        assert_nil r['tutorial_stream_id']
      end
    end
  end

  def test_time_exceeded_grade
    unit = FactoryBot.create(:unit)
    td = TaskDefinition.new({
                              unit_id: unit.id,
                              tutorial_stream: unit.tutorial_streams.first,
                              name: 'Task past due',
                              description: 'Task past due',
                              weighting: 4,
                              target_grade: 0,
                              start_date: Time.zone.now - 2.weeks,
                              target_date: Time.zone.now - 1.week,
                              abbreviation: 'TaskPastDue',
                              restrict_status_updates: false,
                              upload_requirements: [],
                              plagiarism_warn_pct: 0.8,
                              is_graded: true,
                              max_quality_pts: 0
                            })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    project = unit.active_projects.first

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.tutors.first)

    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)
    assert_equal(-1, task.grade)
    assert_equal TaskStatus.time_exceeded, task.task_status

    td.destroy
  end

  def test_extension_reverts_time_exceeded
    unit = FactoryBot.create(:unit, auto_apply_extension_before_deadline: false)
    td = TaskDefinition.new({
                              unit_id: unit.id,
                              tutorial_stream: unit.tutorial_streams.first,
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
                              max_quality_pts: 0
                            })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    # Get the first student - who now has this task
    project = unit.active_projects.first
    tutor = project.tutor_for(td)

    # Add username and auth_token to Header
    add_auth_header_for(user: tutor)

    # Make a submission for this student
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status

    # Get the task... check it is now time exceeded
    task = project.task_for_task_definition(td)
    assert_equal TaskStatus.time_exceeded, task.task_status
    assert_equal 2, task.weeks_can_extend
    assert task.can_apply_for_extension?
    assert_not task.submitted_before_due?

    data_to_post = {
      comment: 'Help me!',
      weeks_requested: 2
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: project.student)

    # Apply for an extension
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    assert_equal 201, last_response.status

    # Reload to get new details
    task.reload
    assert_not task.submitted_before_due?

    assert_equal TaskStatus.time_exceeded, task.task_status

    # Grant extension
    comment_id = last_response_body["id"]
    comment = TaskComment.find(comment_id)
    comment.assess_extension(tutor, true)

    # After extension... no more extensions are possible
    task.reload
    assert_equal 0, task.weeks_can_extend
    assert_not task.can_apply_for_extension?
    assert_equal 2, task.extensions
    assert task.submitted_before_due?

    assert_equal TaskStatus.ready_for_feedback, task.task_status

    td.destroy
  end

  def test_extension_reverts_time_exceeded_auto_apply
    unit = FactoryBot.create(:unit)
    td = TaskDefinition.new({
                              unit_id: unit.id,
                              tutorial_stream: unit.tutorial_streams.first,
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
                              max_quality_pts: 0
                            })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    # Get the first student - who now has this task
    project = unit.active_projects.first
    tutor = project.tutor_for(td)

    # Add username and auth_token to Header
    add_auth_header_for(user: tutor)

    # Make a submission for this student
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status

    # Get the task... check it is now time exceeded
    task = project.task_for_task_definition(td)
    assert_equal TaskStatus.time_exceeded, task.task_status
    assert_equal 2, task.weeks_can_extend
    assert task.can_apply_for_extension?
    assert_not task.submitted_before_due?

    data_to_post = {
      comment: 'Help me!',
      weeks_requested: 2
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: project.student)

    # Apply for an extension
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    assert_equal 201, last_response.status

    # After extension... no more extensions are possible
    task.reload
    assert_equal 0, task.weeks_can_extend
    assert_not task.can_apply_for_extension?
    assert_equal 2, task.extensions
    assert task.submitted_before_due?

    assert_equal TaskStatus.ready_for_feedback, task.task_status

    td.destroy
  end

  def test_convenors_tutors_can_pin_and_unpin_tasks_students_admins_cannot
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 1, perform_submissions: true)
    task = unit.tasks.first

    convenor = FactoryBot.create(:user, :convenor)
    tutor = FactoryBot.create(:user, :tutor)
    student = FactoryBot.create(:user, :student)
    admin = FactoryBot.create(:user, :admin)

    unit.employ_staff(convenor, Role.convenor)
    unit.employ_staff(tutor, Role.tutor)
    unit.enrol_student(student, FactoryBot.create(:campus))

    add_auth_header_for user: convenor

    # Convenor tries to pin task
    post "/api/tasks/#{task.id}/pin"
    assert_equal last_response.status, 201

    # Convenor tries to unpin task
    delete "/api/tasks/#{task.id}/pin"
    assert_equal last_response.status, 200

    add_auth_header_for user: tutor

    # Tutor tries to pin task
    post "/api/tasks/#{task.id}/pin"
    assert_equal last_response.status, 201

    # Tutor tries to unpin task
    delete "/api/tasks/#{task.id}/pin"
    assert_equal last_response.status, 200

    add_auth_header_for user: student

    # Student tries to pin task
    post "/api/tasks/#{task.id}/pin"
    assert_equal 403, last_response.status

    add_auth_header_for user: admin
    # Admin tries to pin task
    post "/api/tasks/#{task.id}/pin"
    assert_equal 403, last_response.status
  end

  def test_convenors_tutors_can_pin_tasks_of_their_units_only
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 1, perform_submissions: true)
    task = unit.tasks.first

    convenor = FactoryBot.create(:user, :convenor)
    tutor = FactoryBot.create(:user, :tutor)

    unit.employ_staff(convenor, Role.convenor)
    unit.employ_staff(tutor, Role.tutor)

    other_unit = FactoryBot.create(:unit, student_count: 1, task_count: 1, perform_submissions: true)
    other_task = other_unit.tasks.first

    add_auth_header_for user: convenor

    # Convenor tries to pin task of unit that they are assigned to
    post "/api/tasks/#{task.id}/pin"
    assert_equal last_response.status, 201

    # Tutor tries to pin task of unit that they are assigned to
    add_auth_header_for user: tutor
    post "/api/tasks/#{task.id}/pin"
    assert_equal last_response.status, 201

    # Convenor tries to pin task of unit that they are not assigned to
    add_auth_header_for user: convenor
    post "/api/tasks/#{other_task.id}/pin"
    assert_equal last_response.status, 403

    # Tutor tries to pin task of unit that they are not assigned to
    add_auth_header_for user: tutor
    post "/api/tasks/#{other_task.id}/pin"
    assert_equal last_response.status, 403
  end

  def test_tasks_for_inbox_include_pinned_status
    unit = FactoryBot.create(:unit, task_count: 2)

    s = unit.active_projects.first
    td1 = unit.task_definitions.first

    task1 = s.task_for_task_definition td1

    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    task1.add_text_comment s.student, "Message"

    # Tutor pins task 1
    add_auth_header_for user: tutor
    post "/api/tasks/#{task1.id}/pin"

    assert TaskPin.find_by user: tutor, task: task1

    # Tutor retrieves task inbox
    get "/api/units/#{unit.id}/tasks/inbox"

    # Assert that task1 is pinned, task2 isn't
    assert last_response_body.count == 1
    assert last_response_body[0]['pinned']
  end

  def test_can_submit_ipynb
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.create!({
                                  unit_id: unit.id,
                                  tutorial_stream: unit.tutorial_streams.first,
                                  name: 'Code task',
                                  description: 'Code task',
                                  weighting: 4,
                                  target_grade: 0,
                                  start_date: Time.zone.now - 2.weeks,
                                  target_date: Time.zone.now + 1.week,
                                  abbreviation: 'CodeTask',
                                  restrict_status_updates: false,
                                  upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
                                  plagiarism_warn_pct: 0.8,
                                  is_graded: true,
                                  max_quality_pts: 0
                                })

    project = unit.active_projects.first

    # Add username and auth_token to Header
    add_auth_header_for(user: project.user)

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/vectorial_graph.ipynb', 'application/json', data_to_post)

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    task = project.task_for_task_definition(td)
    task.convert_submission_to_pdf(log_to_stdout: false)
    assert File.exist? task.final_pdf_path

    unit.destroy
  end

  def test_invalid_latex_in_ipynb
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.create!({
                                  unit_id: unit.id,
                                  tutorial_stream: unit.tutorial_streams.first,
                                  name: 'Code task',
                                  description: 'Code task',
                                  weighting: 4,
                                  target_grade: 0,
                                  start_date: Time.zone.now - 2.weeks,
                                  target_date: Time.zone.now + 1.week,
                                  abbreviation: 'CodeTask',
                                  restrict_status_updates: false,
                                  upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
                                  plagiarism_warn_pct: 0.8,
                                  is_graded: true,
                                  max_quality_pts: 0
                                })

    project = unit.active_projects.first

    # Add username and auth_token to Header
    add_auth_header_for(user: project.user)

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/invalid_notebook.ipynb', 'application/json', data_to_post)

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    task = project.task_for_task_definition(td)
    task.convert_submission_to_pdf(log_to_stdout: true)
    assert File.exist? task.final_pdf_path

    unit.destroy
  end

  def test_download_task_pdf
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.create!({
                                  unit_id: unit.id,
                                  tutorial_stream: unit.tutorial_streams.first,
                                  name: 'Code task',
                                  description: 'Code task',
                                  weighting: 4,
                                  target_grade: 0,
                                  start_date: Time.zone.now - 2.weeks,
                                  target_date: Time.zone.now + 1.week,
                                  abbreviation: 'CodeTask',
                                  restrict_status_updates: false,
                                  upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
                                  plagiarism_warn_pct: 0.8,
                                  is_graded: true,
                                  max_quality_pts: 0
                                })

    project = unit.active_projects.first
    task = project.task_for_task_definition(td)

    # Add username and auth_token to Header
    add_auth_header_for(user: project.user)

    get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission"

    assert_equal 200, last_response.status
    assert_equal File.size(Rails.root.join('public/resources/FileNotFound.pdf')), last_response.length

    dir = FileHelper.student_work_dir(:new, task, true)

    get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission"

    assert_equal 200, last_response.status
    assert_equal File.size(Rails.root.join('public/resources/AwaitingProcessing.pdf')), last_response.length

    FileUtils.rm_r dir

    src_file = Rails.root.join('test_files/submissions/1.2P.pdf')
    FileUtils.cp src_file, task.final_pdf_path

    get "/api/projects/#{project.id}/task_def_id/#{td.id}/submission"

    assert_equal 200, last_response.status
    assert_equal File.size(src_file), last_response.length

    unit.destroy
  end

  def test_cant_submit_until_prerequisites_submitted
    Sidekiq::Testing.inline! do
      # Create a unit and two task definitions
      unit = FactoryBot.create(:unit, student_count: 1, task_count: 2)
      td1 = unit.task_definitions.first
      td2 = unit.task_definitions.second
      project = unit.active_projects.first

      task = project.task_for_task_definition(td2)

      td1.update(
        upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
        target_grade: 0, # Pass
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now + 1.week
      )

      td2.update(
        upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
        target_grade: 3, # HD
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now + 1.week
      )

      # Create a prerequisite on the second taskDef that adds the first taskDef as a prereq
      prereq = TaskPrerequisite.create!(
        task_definition: td2, # Before you can submit td2...
        prerequisite: td1, # You need to submit td1
        task_status_id: TaskStatus.ready_for_feedback.id
      )

      assert prereq.valid?

      # Add username and auth_token to Header
      add_auth_header_for(user: project.user)

      data_to_post = {
        trigger: 'ready_for_feedback'
      }

      data_to_post = with_file('test_files/submissions/program.cs', 'application/json', data_to_post)

      # Attempt to make a submission that has an unsubmitted prerequisite
      post "/api/projects/#{project.id}/task_def_id/#{td2.id}/submission", data_to_post
      assert_equal 409, last_response.status, last_response_body
      task = project.task_for_task_definition(td2)
      # Ensure the submission was denied
      assert_equal TaskStatus.not_started, task.task_status
      assert_equal last_response_body['error'], "Cannot submit this task until prerequisite '#{td1.abbreviation}' has been submitted"

      prereq.update(task_status_id: TaskStatus.discuss.id)
      post "/api/projects/#{project.id}/task_def_id/#{td2.id}/submission", data_to_post
      assert_equal 409, last_response.status, last_response_body
      task.reload
      # Ensure the submission was denied
      assert_equal TaskStatus.not_started, task.task_status
      assert_equal last_response_body['error'], "Cannot submit this task until prerequisite '#{td1.abbreviation}' has been discussed"

      prereq.update(task_status_id: TaskStatus.demonstrate.id)
      post "/api/projects/#{project.id}/task_def_id/#{td2.id}/submission", data_to_post
      assert_equal 409, last_response.status, last_response_body
      task.reload
      # Ensure the submission was denied
      assert_equal TaskStatus.not_started, task.task_status
      assert_equal last_response_body['error'], "Cannot submit this task until prerequisite '#{td1.abbreviation}' has been demonstrated"

      prereq.update(task_status_id: TaskStatus.complete.id)
      post "/api/projects/#{project.id}/task_def_id/#{td2.id}/submission", data_to_post
      assert_equal 409, last_response.status, last_response_body
      task.reload
      # Ensure the submission was denied
      assert_equal TaskStatus.not_started, task.task_status
      assert_equal last_response_body['error'], "Cannot submit this task until prerequisite '#{td1.abbreviation}' has been completed"

      prereq.update(task_status_id: TaskStatus.ready_for_feedback.id)

      # Make a submission to the prerequsite task
      post "/api/projects/#{project.id}/task_def_id/#{td1.id}/submission", data_to_post
      assert_equal 201, last_response.status, last_response_body
      task1 = project.task_for_task_definition(td1)
      assert_equal TaskStatus.ready_for_feedback, task1.task_status

      # Re-attempt to make a submission (Prerequisite status is ready for feedback, expecting complete)
      post "/api/projects/#{project.id}/task_def_id/#{td2.id}/submission", data_to_post
      assert_equal 201, last_response.status, last_response_body
      task.reload
      assert_equal TaskStatus.ready_for_feedback, task.task_status

      prereq.destroy
      unit.destroy
    end
  end

  def test_prerequisites_task_status
    # Create a unit and two task definitions
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 10)
    td1 = unit.task_definitions.first
    td2 = unit.task_definitions.second

    td1.update(
      upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
      target_grade: 0, # Pass
      start_date: Time.zone.now - 2.weeks,
      target_date: Time.zone.now + 1.week
    )

    td2.update(
      upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
      target_grade: 3, # HD
      start_date: Time.zone.now - 2.weeks,
      target_date: Time.zone.now + 1.week
    )

    project = unit.active_projects.first

    # Add username and auth_token to Header
    add_auth_header_for(user: project.user)

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    # Create a prerequisite on the second taskDef that adds the first taskDef as a prereq
    prereq = TaskPrerequisite.create!(
      task_definition: td2, # Before you can submit td2...
      prerequisite: td1, # You need to submit td1
      task_status_id: TaskStatus.ready_for_feedback.id
    )

    assert prereq.valid?

    tests = [
      {
        prerequisite_status: TaskStatus.ready_for_feedback,
        required_status: TaskStatus.ready_for_feedback,
        expected_status: 201,
        expected_error: nil
      },
      {
        prerequisite_status: TaskStatus.discuss,
        required_status: TaskStatus.discuss,
        expected_status: 201,
        expected_error: nil
      },
      {
        prerequisite_status: TaskStatus.demonstrate,
        required_status: TaskStatus.demonstrate,
        expected_status: 201,
        expected_error: nil
      },
      {
        prerequisite_status: TaskStatus.discuss,
        required_status: TaskStatus.demonstrate,
        expected_status: 201,
        expected_error: nil
      },
      {
        prerequisite_status: TaskStatus.demonstrate,
        required_status: TaskStatus.discuss,
        expected_status: 201,
        expected_error: nil
      },
      {
        prerequisite_status: TaskStatus.complete,
        required_status: TaskStatus.complete,
        expected_status: 201,
        expected_error: nil
      },
      {
        prerequisite_status: TaskStatus.complete,
        required_status: TaskStatus.ready_for_feedback,
        expected_status: 201,
        expected_error: nil
      },
      {
        prerequisite_status: TaskStatus.discuss,
        required_status: TaskStatus.ready_for_feedback,
        expected_status: 201,
        expected_error: nil
      }
    ]

    Sidekiq::Testing.inline! do
      prereq_task = project.task_for_task_definition(td1)
      task = project.task_for_task_definition(td2)
      data_to_post = with_file('test_files/submissions/program.cs', 'application/json', data_to_post)

      tests.each do |test|
        prereq_task.update(task_status_id: test[:prerequisite_status].id)
        task.update(task_status_id: TaskStatus.not_started.id)

        post "/api/projects/#{project.id}/task_def_id/#{td2.id}/submission", data_to_post
        assert_equal test[:expected_status], last_response.status, last_response_body
        task.reload
        if test[:expected_status] == 201
          # Ensure submission was accepted
          assert_equal TaskStatus.ready_for_feedback, task.task_status
        else
          # Ensure submission was denied
          assert_equal TaskStatus.not_started, task.task_status
        end
      end

      prereq.destroy
      unit.destroy
    end
  end

  def test_check_in_comment
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.create!({
                                  unit_id: unit.id,
                                  tutorial_stream: unit.tutorial_streams.first,
                                  name: 'Code task',
                                  description: 'Code task',
                                  weighting: 4,
                                  target_grade: 0,
                                  start_date: Time.zone.now - 2.weeks,
                                  target_date: Time.zone.now + 1.week,
                                  abbreviation: 'CodeTask',
                                  restrict_status_updates: false,
                                  upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
                                  plagiarism_warn_pct: 0.8,
                                  is_graded: true,
                                  max_quality_pts: 0
                                })

    project = unit.active_projects.first
    task = project.task_for_task_definition(td)

    student = project.student
    tutor = unit.tutors.first

    # Ensure student can not add this type of comment
    add_auth_header_for(user: student)
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/check_in"
    assert_equal 403, last_response.status

    # Ensure not comment was created
    lc = task.comments.last
    assert lc.nil?

    # Ensure tutor can add this type of comment
    add_auth_header_for(user: tutor)
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/check_in"
    assert_equal 201, last_response.status

    lc = task.comments.last

    # Ensure comment was created
    assert_not lc.nil?
    assert lc.valid?
    assert "Checked In", lc.comment
    assert TaskCheckedInComment, lc.type
  end

  def test_require_comment_for_feedback_submission_assess_in_portfolio
    Sidekiq::Testing.inline! do
      unit = FactoryBot.create(:unit, student_count: 1, task_count: 2)
      td1 = unit.task_definitions.first
      project = unit.active_projects.first

      task = project.task_for_task_definition(td1)

      td1.update(
        upload_requirements: [{ "key" => 'file0', "name" => 'Shape Class', "type" => 'code' }],
        target_grade: 0, # Pass
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now + 1.week,
        assess_in_portfolio_only: false
      )

      add_auth_header_for(user: project.user)

      # Make a submission where a comment isn't required
      post "/api/projects/#{project.id}/task_def_id/#{td1.id}/submission",
           with_file('test_files/submissions/program.cs', 'application/json', {
                       trigger: 'ready_for_feedback'
                     })
      assert_equal 201, last_response.status, last_response_body
      task.reload
      assert_equal TaskStatus.ready_for_feedback, task.task_status

      task.update(task_status: TaskStatus.not_started)

      td1.update(assess_in_portfolio_only: true)

      # Make a submission where a comment is required
      post "/api/projects/#{project.id}/task_def_id/#{td1.id}/submission",
           with_file('test_files/submissions/program.cs', 'application/json', {
                       trigger: 'ready_for_feedback'
                     })
      assert_equal 422, last_response.status, last_response_body
      task.reload
      assert_equal TaskStatus.not_started, task.task_status

      comment = 'I would like feedback with my code..'

      # Make a submission with comment
      post "/api/projects/#{project.id}/task_def_id/#{td1.id}/submission",
           with_file('test_files/submissions/program.cs', 'application/json', {
                       trigger: 'ready_for_feedback',
                       comment: comment
                     })
      assert_equal 201, last_response.status, last_response_body
      task.reload
      assert_equal TaskStatus.ready_for_feedback, task.task_status

      status_comment = task.comments.last
      text_comment = task.comments.second_to_last

      assert_not status_comment.nil?
      assert_not text_comment.nil?

      assert_equal TaskStatus.ready_for_feedback.name, status_comment.comment
      assert_equal comment, text_comment.comment
    end
  end

  def test_resubmission_doesnt_change_submission_date
    Sidekiq::Testing.inline! do
      unit = FactoryBot.create(:unit, task_count: 2, student_count: 0)
      tutor = FactoryBot.create(:user, :tutor)

      unit_role = unit.employ_staff(tutor, Role.tutor)
      tutorial_stream = FactoryBot.create(:tutorial_stream, unit: unit)
      tutorial = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream, campus: nil, unit_role: unit_role)

      td = unit.task_definitions.first

      td.update!(due_date: Time.zone.today + 1.day, tutorial_stream: tutorial_stream)
      assert_not td.nil?

      student1 = FactoryBot.create(:user, :student)
      student2 = FactoryBot.create(:user, :student)

      project1 = unit.enrol_student(student1, nil)
      project2 = unit.enrol_student(student2, nil)

      project1.enrol_in(tutorial)
      project2.enrol_in(tutorial)

      tasks = unit.tasks_for_task_inbox(tutor, false)

      assert tasks.to_a.empty?

      # Submit a task before the due date (student 1)
      add_auth_header_for(user: student1)
      data_to_post = {
        trigger: 'ready_for_feedback'
      }
      data_to_post = with_file('test_files/submissions/program.cs', 'application/json', data_to_post)
      post "/api/projects/#{project1.id}/task_def_id/#{td.id}/submission", data_to_post
      assert_equal 201, last_response.status, last_response_body

      travel 10.minutes

      # Submit a task before the due date (student 2)
      add_auth_header_for(user: student2)
      data_to_post = {
        trigger: 'ready_for_feedback'
      }
      data_to_post = with_file('test_files/submissions/program.cs', 'application/json', data_to_post)
      post "/api/projects/#{project2.id}/task_def_id/#{td.id}/submission", data_to_post
      assert_equal 201, last_response.status, last_response_body

      tasks = unit.tasks_for_task_inbox(tutor, false)

      assert_equal 2, tasks.to_a.count

      assert_equal project1.id, tasks.first.project.id, "First task in inbox should be project1's task"
      assert_equal project2.id, tasks.second.project.id, "Second task in inbox should be project2's task"

      task1 = project1.task_for_task_definition(td)
      task2 = project2.task_for_task_definition(td)

      assert_equal TaskStatus.ready_for_feedback, task1.task_status
      assert_equal TaskStatus.ready_for_feedback, task2.task_status

      assert task2.submission_date > task1.submission_date

      # Submit the task again, ensure the submission_date hasn't changed (student1)
      travel 10.minutes

      # Submit a task before the due date (student 1)
      add_auth_header_for(user: student1)
      data_to_post = {
        trigger: 'ready_for_feedback'
      }
      data_to_post = with_file('test_files/submissions/program.cs', 'application/json', data_to_post)
      post "/api/projects/#{project1.id}/task_def_id/#{td.id}/submission", data_to_post
      assert_equal 201, last_response.status, last_response_body

      tasks = unit.tasks_for_task_inbox(tutor, false)

      assert_equal project1.id, tasks.first.project.id, "First task in inbox should be project1's task"
      assert_equal project2.id, tasks.second.project.id, "Second task in inbox should be project2's task"

      task1 = project1.task_for_task_definition(td)
      task2 = project2.task_for_task_definition(td)
      assert task2.submission_date > task1.submission_date
      assert TaskStatus.ready_for_feedback, task1.task_status

      # Submit the task again after the duedate, ensure the submission_date hasn't changed (student1)
      travel 2.days

      # Submit a task before the due date (student 1)
      add_auth_header_for(user: student1)
      data_to_post = {
        trigger: 'ready_for_feedback'
      }
      data_to_post = with_file('test_files/submissions/program.cs', 'application/json', data_to_post)
      post "/api/projects/#{project1.id}/task_def_id/#{td.id}/submission", data_to_post
      assert_equal 201, last_response.status, last_response_body

      tasks = unit.tasks_for_task_inbox(tutor, false)

      assert_equal project1.id, tasks.first.project.id, "First task in inbox should be project1's task"
      assert_equal project2.id, tasks.second.project.id, "Second task in inbox should be project2's task"

      task1 = project1.task_for_task_definition(td)
      task2 = project2.task_for_task_definition(td)
      assert task2.submission_date > task1.submission_date
      assert TaskStatus.ready_for_feedback, task1.task_status

      task1.update(task_status_id: TaskStatus.fix_and_resubmit.id)

      # Submit the task again, now expecting submission date to update
      travel 10.minutes

      # Submit a task before the due date (student 1)
      add_auth_header_for(user: student1)
      data_to_post = {
        trigger: 'ready_for_feedback'
      }
      data_to_post = with_file('test_files/submissions/program.cs', 'application/json', data_to_post)
      post "/api/projects/#{project1.id}/task_def_id/#{td.id}/submission", data_to_post
      assert_equal 201, last_response.status, last_response_body

      tasks = unit.tasks_for_task_inbox(tutor, false)

      assert_equal project2.id, tasks.first.project.id, "First task in inbox should be project1's task"
      assert_equal project1.id, tasks.second.project.id, "Second task in inbox should be project2's task"

      task1 = project1.task_for_task_definition(td)
      task2 = project2.task_for_task_definition(td)
      assert task1.submission_date > task2.submission_date
    end
  end
end
