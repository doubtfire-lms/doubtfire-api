require 'test_helper'

class ExtensionTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_extension_application
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: project.tutorial_enrolments.first.tutorial.tutorial_stream,
        name: 'status task change',
        description: 'status task change test',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 1.day,
        abbreviation: 'LESS1WEEKEXTTEST',
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!
    data_to_post = {
      weeks_requested: '1',
      comment: "I need a lot of help"
    }

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    # Request a 2 day extension
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 1, "Error: Deadline less than a week, requested weeks should be 1, found #{response["weeks_requested"]}."

    # Request a 2 week extension on the day
    td.due_date = Time.zone.now + 2.weeks
    td.save!
    data_to_post["weeks_requested"] = '2'

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 2, "Error: Weeks requested weeks should be 2, found #{response["weeks_requested"]}."

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    # Ask for too long an extension
    data_to_post["weeks_requested"] = '5'
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    response = last_response_body
    assert_equal 403, last_response.status, "Error: Allowed too long of a request to be applied."


    # Add auth_token and username to header
    add_auth_header_for(user: user)

    # Ask for 0 week extension
    data_to_post["weeks_requested"] = '0'
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    response = last_response_body
    assert_equal 403, last_response.status, "Error: Should not allow 0 week extension requests"

    td.destroy!
    unit.destroy!
  end

  # Test that extension requests are not read by main tutor until they are assessed
  def test_extension_application
    unit = FactoryBot.create(:unit, auto_apply_extension_before_deadline: false)
    project = unit.projects.first
    user = project.student
    other_tutor = unit.main_convenor_user

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'status task change',
        description: 'status task change test',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 1.day,
        abbreviation: 'LESS1WEEKEXTTEST',
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    main_tutor = project.tutor_for(td)
    data_to_post = {
      weeks_requested: '1',
      comment: "I need a lot of help"
    }

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    # Request a 2 day extension
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 1, "Error: Deadline less than a week, requested weeks should be 1, found #{response["weeks_requested"]}."

    tc = TaskComment.find(response['id'])

    # Check it is not read by the main tutor
    refute tc.read_by?(main_tutor), "Error: Should not be read by main tutor on create"
    assert tc.read_by?(user), "Error: Should be read by student on create"

    # Check that reading by main tutor does not read the task
    tc.read_by? main_tutor
    refute tc.read_by?(main_tutor), "Error: Should not be read by main tutor even when they read it"

    # Check it is read after grant by another user
    tc.assess_extension other_tutor, true
    assert tc.read_by?(main_tutor), "Error: Should be read by main tutor after assess"

    td.destroy!
    unit.destroy!
  end

  def test_disallow_student_extensions
    unit = FactoryBot.create(:unit, allow_student_extension_requests: false)
    project = unit.projects.first
    user = project.student
    other_tutor = unit.main_convenor_user

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'status task change',
        description: 'status task change test',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 1.day,
        abbreviation: 'LESS1WEEKEXTTEST',
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    main_tutor = project.tutor_for(td)
    data_to_post = {
      weeks_requested: '1',
      comment: "I need a lot of help"
    }

    # Request a 2 day extension
    add_auth_header_for user: user
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    response = last_response_body
    assert_equal 403, last_response.status

    add_auth_header_for user: main_tutor
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 1, "Error: Deadline less than a week, requested weeks should be 1, found #{response["weeks_requested"]}."

    tc = ExtensionComment.find(response['id'])

    # Check it is read after grant by another user - should be auto granted
    assert tc.read_by?(main_tutor), "Error: Should be read by main tutor after assess"
    assert tc.extension_granted, "Shoudl be granted"

    td.destroy!
    unit.destroy!
  end

  def test_extension_on_resubmit
    unit = FactoryBot.create(:unit, extension_weeks_on_resubmit_request: 2)
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task past due - for revert',
        description: 'Task past due',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now + 1.day,
        due_date: Time.zone.now + 1.day + 3.weeks,
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

    # Make a submission for this student
    add_auth_header_for user: tutor
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status

    # Get the task... check it is ready for feedback
    task = project.task_for_task_definition(td)
    assert_equal TaskStatus.ready_for_feedback, task.task_status
    assert_equal 3, task.weeks_can_extend
    assert task.can_apply_for_extension?

    # Ask for resubmit
    task.assess TaskStatus.fix_and_resubmit, tutor

    # Now check that the 2 weeks was added
    assert_equal 1, task.weeks_can_extend

    td.destroy
    unit.destroy
  end

  def test_extension_in_inbox
    unit = FactoryBot.create(:unit, auto_apply_extension_before_deadline: false, unenrolled_student_count: 0, part_enrolled_student_count: 0, inactive_student_count: 0, tutorials: 2, staff_count: 2, task_count:0)
    project = unit.projects.first
    user = project.student
    tutor = unit.main_convenor_user

    assert project.enrolled

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'status task change',
        description: 'status task change test',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 2.week,
        abbreviation: 'LESS1WEEKEXTTEST',
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      weeks_requested: '1',
      comment: "I need a lot of help"
    }

    inbox = unit.tasks_as_hash(unit.tasks_for_task_inbox(tutor))
    assert_equal 0, inbox.count, inbox.inspect

    # Request a 1 week extension
    add_auth_header_for user: user
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 1, "Error: Deadline less than a week, requested weeks should be 1, found #{response["weeks_requested"]}."

    unit.reload
    task = unit.tasks.last

    inbox = unit.tasks_as_hash(unit.tasks_for_task_inbox(tutor))
    assert_equal 1, inbox.count, inbox.inspect

    assert inbox[0][:has_extensions], inbox.inspect

    # Test task explorer
    add_auth_header_for user: tutor
    get "/api/units/#{unit.id}/task_definitions/#{td.id}/tasks"

    assert_equal 200, last_response.status
    assert_equal 1, last_response_body.count, last_response_body

    assert last_response_body[0]['has_extensions'], last_response_body.inspect

    td.destroy!
    unit.destroy!
  end

end
