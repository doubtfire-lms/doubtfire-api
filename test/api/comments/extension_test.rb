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

    # Request a 2 day extension
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 1, "Error: Deadline less than a week, requested weeks should be 1, found #{response["weeks_requested"]}."

    # Request a 2 week extension on the day
    td.due_date = Time.zone.now + 2.weeks
    td.save!
    data_to_post["weeks_requested"] = '2'

    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 2, "Error: Weeks requested weeks should be 2, found #{response["weeks_requested"]}."

    # Ask for too long an extension
    data_to_post["weeks_requested"] = '5'
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 403, last_response.status, "Error: Allowed too long of a request to be applied."

    # Ask for 0 week extension
    data_to_post["weeks_requested"] = '0'
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
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

    # Request a 2 day extension
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
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
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 403, last_response.status

    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", main_tutor), data_to_post
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
      trigger: 'ready_to_mark'
    }

    # Get the first student - who now has this task
    project = unit.active_projects.first
    tutor = project.tutor_for(td)

    # Make a submission for this student
    post with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/submission", tutor), data_to_post    
    assert_equal 201, last_response.status

    # Get the task... check it is ready for feedback
    task = project.task_for_task_definition(td)
    assert_equal TaskStatus.ready_to_mark, task.task_status
    assert_equal 3, task.weeks_can_extend
    assert task.can_apply_for_extension?

    # Ask for resubmit
    task.assess TaskStatus.fix_and_resubmit, tutor

    # Now check that the 2 weeks was added
    assert_equal 1, task.weeks_can_extend

    td.destroy
    unit.destroy
  end
end
