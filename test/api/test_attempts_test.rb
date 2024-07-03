require 'test_helper'

class TestAttemptsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_task_attempts
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Test attempts',
        description: 'Test attempts',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TestAttempts',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: true,
        scorm_attempt_limit: 0
      }
    )
    td.save!

    add_auth_header_for(user: user)

    # When no attempts exist
    get "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts"
    assert_equal 200, last_response.status
    assert_empty last_response_body

    task = project.task_for_task_definition(td)
    attempt = TestAttempt.create({ task_id: task.id })

    td1 = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Test attempts new',
        description: 'Test attempts new',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TestAttemptsNew',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: true,
        scorm_attempt_limit: 0
      }
    )
    td1.save!

    task1 = project.task_for_task_definition(td1)
    attempt1 = TestAttempt.create({ task_id: task1.id })

    add_auth_header_for(user: user)

    # When attempts exists
    get "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts"
    assert_equal 200, last_response.status
    assert_json_equal last_response_body, [attempt]

    user1 = FactoryBot.create(:user, :student)

    add_auth_header_for(user: user1)

    # When user is unauthorised
    get "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts"
    assert_equal 403, last_response.status

    user1.destroy!
    td.destroy!
    td1.destroy!
    unit.destroy!
  end

  def test_get_latest
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Test attempts',
        description: 'Test attempts',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TestAttempts',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: true,
        scorm_attempt_limit: 0
      }
    )
    td.save!

    add_auth_header_for(user: user)

    # When no attempts exist
    get "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts/latest"
    assert_equal 404, last_response.status

    task = project.task_for_task_definition(td)
    attempt = TestAttempt.create({ task_id: task.id })
    attempt.terminated = true
    attempt.completion_status = true
    attempt.save!
    attempt1 = TestAttempt.create({ task_id: task.id })

    add_auth_header_for(user: user)

    # When attempts exist
    get "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts/latest"
    assert_equal 200, last_response.status
    assert_json_equal last_response_body, attempt1

    add_auth_header_for(user: user)

    # Get completed latest
    get "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts/latest?completed=true"
    assert_equal 200, last_response.status
    assert_json_equal last_response_body, attempt

    user1 = FactoryBot.create(:user, :student)

    add_auth_header_for(user: user1)

    # When user is unauthorised
    get "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts/latest"
    assert_equal 403, last_response.status

    td.destroy!
    unit.destroy!
  end

  def test_review_attempt
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Test attempts',
        description: 'Test attempts',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TestAttempts',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: true,
        scorm_attempt_limit: 0,
        scorm_allow_review: true
      }
    )
    td.save!

    add_auth_header_for(user: user)

    # When attempt id is invalid
    get "api/test_attempts/0/review"
    assert_equal 404, last_response.status

    task = project.task_for_task_definition(td)
    attempt = TestAttempt.create({ task_id: task.id })

    td.scorm_allow_review = false
    td.save!

    add_auth_header_for(user: user)

    # When review is disabled
    get "api/test_attempts/#{attempt.id}/review"
    assert_equal 403, last_response.status

    td.scorm_allow_review = true
    td.save!

    add_auth_header_for(user: user)

    # When attempt is incomplete
    get "api/test_attempts/#{attempt.id}/review"
    assert_equal 500, last_response.status

    dm = JSON.parse(attempt.cmi_datamodel)
    dm['cmi.completion_status'] = 'completed'
    attempt.cmi_datamodel = dm.to_json
    attempt.completion_status = true
    attempt.terminated = true
    attempt.save!

    add_auth_header_for(user: user)

    # When attempt can be reviewed
    get "api/test_attempts/#{attempt.id}/review"
    assert_equal 200, last_response.status

    attempt.review
    attempt.save!

    assert_json_equal last_response_body, attempt

    tutor = project.tutor_for(td)

    add_auth_header_for(user: tutor)

    # When user is tutor
    get "api/test_attempts/#{attempt.id}/review"
    assert_equal 200, last_response.status
    assert_json_equal last_response_body, attempt

    user1 = FactoryBot.create(:user, :student)

    add_auth_header_for(user: user1)

    # When user is unauthorised
    get "api/test_attempts/#{attempt.id}/review"
    assert_equal 403, last_response.status

    td.destroy!
    unit.destroy!
  end

  def test_post_attempt
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Test attempts',
        description: 'Test attempts',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TestAttempts',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: false,
        scorm_attempt_limit: 1
      }
    )
    td.save!

    add_auth_header_for(user: user)

    # When scorm is disabled
    post "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts"
    assert_equal 403, last_response.status

    td.scorm_enabled = true
    td.save!

    tutor = project.tutor_for(td)

    add_auth_header_for(user: tutor)

    # When user is unauthorised
    post "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts"
    assert_equal 403, last_response.status

    task = project.task_for_task_definition(td)

    add_auth_header_for(user: user)

    # When new attempt can be made
    post "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts"
    assert_equal 201, last_response.status
    assert last_response_body["task_id"] == task.id

    attempt = TestAttempt.find(last_response_body["id"])

    add_auth_header_for(user: user)

    # When last attempt is incomplete
    post "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts"
    assert_equal 400, last_response.status

    attempt.terminated = true
    attempt.success_status = true
    attempt.save!

    add_auth_header_for(user: user)

    # When last attempt is a pass
    post "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts"
    assert_equal 400, last_response.status

    attempt.success_status = false
    attempt.save!

    add_auth_header_for(user: user)

    # When attempt limit is reached
    post "api/projects/#{project.id}/task_def_id/#{td.id}/test_attempts"
    assert_equal 400, last_response.status

    td.destroy!
    unit.destroy!
  end

  def test_update_attempt
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Test attempts',
        description: 'Test attempts',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TestAttempts',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: true,
        scorm_attempt_limit: 0
      }
    )
    td.save!

    tutor = project.tutor_for(td)

    task = project.task_for_task_definition(td)
    attempt = TestAttempt.create({ task_id: task.id })

    dm = JSON.parse(attempt.cmi_datamodel)
    dm["cmi.completion_status"] = "completed"
    dm["cmi.score.scaled"] = "0.1"

    data_to_patch = {
      cmi_datamodel: dm.to_json,
      terminated: true
    }

    add_auth_header_for(user: tutor)

    # When user is unauthorised
    patch "api/test_attempts/#{attempt.id}", data_to_patch
    assert_equal 403, last_response.status

    add_auth_header_for(user: user)

    # When attempt is terminated
    patch "api/test_attempts/#{attempt.id}", data_to_patch
    assert_equal 200, last_response.status

    attempt = TestAttempt.find(attempt.id)

    assert attempt.terminated == true
    assert JSON.parse(attempt.cmi_datamodel)["cmi.completion_status"] == "completed"

    tc = ScormComment.find_by(test_attempt_id: attempt.id)

    assert_not_nil tc

    add_auth_header_for(user: user)

    # When unauthorised user tries to override pass status
    patch "api/test_attempts/#{attempt.id}", { success_status: true }
    assert_equal 403, last_response.status

    add_auth_header_for(user: tutor)

    # When authorised user tries to override pass status
    patch "api/test_attempts/#{attempt.id}", { success_status: true }
    assert_equal 200, last_response.status

    attempt = TestAttempt.find(attempt.id)

    assert attempt.success_status == true
    assert JSON.parse(attempt.cmi_datamodel)["cmi.success_status"] == "passed"

    tc = ScormComment.find_by(test_attempt_id: attempt.id)

    assert tc.comment == attempt.success_status_description

    add_auth_header_for(user: tutor)

    # When attempt id is invalid
    patch "api/test_attempts/0", { success_status: true }
    assert_equal 404, last_response.status

    td.destroy!
    unit.destroy!
  end

  def test_delete_attempt
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Test attempts',
        description: 'Test attempts',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'TestAttempts',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: true,
        scorm_attempt_limit: 0
      }
    )
    td.save!

    task = project.task_for_task_definition(td)
    attempt = TestAttempt.create({ task_id: task.id })

    add_auth_header_for(user: user)

    # When user is unauthorised
    delete "api/test_attempts/#{attempt.id}"
    assert_equal 403, last_response.status

    tutor = project.tutor_for(td)

    add_auth_header_for(user: tutor)

    # When user is authorised
    delete "api/test_attempts/#{attempt.id}"
    assert_equal 200, last_response.status

    add_auth_header_for(user: tutor)

    # When attempt id is invalid
    delete "api/test_attempts/0"
    assert_equal 404, last_response.status

    td.destroy!
    unit.destroy!
  end
end
