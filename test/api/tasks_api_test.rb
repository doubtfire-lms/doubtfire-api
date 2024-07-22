require 'test_helper'

class TasksApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

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

    last_response_body.each_with_index do |r, i|
      t = Task.find(r['id'])
      assert_json_matches_model t, r, ['id', 'task_definition_id']
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

  def test_task_get_with_streams
    # The GET we are testing
    unit = FactoryBot.create(:unit, perform_submissions: true, stream_count: 1, campus_count: 2)

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    get "/api/tasks?unit_id=#{unit.id}"
    expected_data = unit.student_tasks.where('task_status_id > ?', 1)

    assert_equal expected_data.count, last_response_body.count

    last_response_body.each_with_index do |r, i|
      t = Task.find(r['id'])
      assert_json_matches_model t, r, ['id', 'task_definition_id']
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
        upload_requirements: [ ],
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
    assert_equal -1, task.grade
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
        upload_requirements: [ ],
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
    refute task.submitted_before_due?

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
    refute task.submitted_before_due?

    assert_equal TaskStatus.time_exceeded, task.task_status

    # Grant extension
    comment_id = last_response_body["id"]
    comment = TaskComment.find(comment_id)
    comment.assess_extension(tutor, true)

    # After extension... no more extensions are possible
    task.reload
    assert_equal 0, task.weeks_can_extend
    refute task.can_apply_for_extension?
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
        upload_requirements: [ ],
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
    refute task.submitted_before_due?

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
    refute task.can_apply_for_extension?
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
        upload_requirements: [ { "key" => 'file0', "name" => 'Shape Class', "type" => 'code' } ],
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

    td.destroy
  end


end
