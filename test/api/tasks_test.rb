require 'test_helper'

class TasksTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_task_get
    # The GET we are testing
    unit = FactoryBot.create(:unit, perform_submissions: true)

    # Add username and auth_token to Header
    add_auth_header_for({}, unit.main_convenor_user)

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
        assert_equal tutorial.tutorial_stream_id, r['tutorial_stream_id']
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
    add_auth_header_for({}, unit.main_convenor_user)

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
        assert_equal tutorial.tutorial_stream_id, r['tutorial_stream_id']
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
      trigger: 'ready_to_mark'
    }

    project = unit.active_projects.first

    # Add username and auth_token to Header
    add_auth_header_for({}, unit.tutors.first)

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
      trigger: 'ready_to_mark'
    }

    # Get the first student - who now has this task
    project = unit.active_projects.first
    tutor = project.tutor_for(td)

    # Add username and auth_token to Header
    add_auth_header_for({}, tutor)

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
    add_auth_header_for({}, project.student)

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

    assert_equal TaskStatus.ready_to_mark, task.task_status

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
      trigger: 'ready_to_mark'
    }

    # Get the first student - who now has this task
    project = unit.active_projects.first
    tutor = project.tutor_for(td)

    # Add username and auth_token to Header
    add_auth_header_for({}, tutor)

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
    add_auth_header_for({}, project.student)

    # Apply for an extension
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    assert_equal 201, last_response.status

    # After extension... no more extensions are possible
    task.reload
    assert_equal 0, task.weeks_can_extend
    refute task.can_apply_for_extension?
    assert_equal 2, task.extensions
    assert task.submitted_before_due?

    assert_equal TaskStatus.ready_to_mark, task.task_status

    td.destroy
  end

end
