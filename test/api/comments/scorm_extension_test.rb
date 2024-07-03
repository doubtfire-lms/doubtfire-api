require 'test_helper'

class ScormExtensionTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_scorm_extension_request
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Scorm extension request',
        description: 'Scorm extension request',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'ScormExtensionRequest',
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

    data_to_post = {
      comment: 'I need more attempts please'
    }

    add_auth_header_for(user: user)

    # When there is no attempt limit
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_scorm_extension", data_to_post
    assert_equal 400, last_response.status

    td.scorm_attempt_limit = 1
    td.save!

    add_auth_header_for(user: user)

    # When there is an attempt limit
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_scorm_extension", data_to_post
    assert_equal 201, last_response.status
    assert last_response_body["type"] == "scorm_extension"

    admin = FactoryBot.create(:user, :admin)

    add_auth_header_for(user: admin)

    # When the user is unauthorised
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_scorm_extension", data_to_post
    assert_equal 403, last_response.status

    td.destroy!
    unit.destroy!
  end

  # Test that extension requests are not read by main tutor until they are assessed
  def test_read_by_main_tutor
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student
    other_tutor = unit.main_convenor_user

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Scorm extension request',
        description: 'Scorm extension request',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'ScormExtensionRequest',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: true,
        scorm_attempt_limit: 1
      }
    )
    td.save!

    main_tutor = project.tutor_for(td)
    data_to_post = {
      comment: 'I need more attempts please'
    }

    add_auth_header_for(user: user)

    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_scorm_extension", data_to_post
    assert_equal 201, last_response.status
    assert last_response_body["type"] == "scorm_extension"

    tc = TaskComment.find(last_response_body["id"])

    # Check it is not read by the main tutor
    refute tc.read_by?(main_tutor), "Error: Should not be read by main tutor on create"
    assert tc.read_by?(user), "Error: Should be read by student on create"

    # Check that reading by main tutor does not read the task
    tc.read_by? main_tutor
    refute tc.read_by?(main_tutor), "Error: Should not be read by main tutor even when they read it"

    # Check it is read after grant by another user
    tc.assess_scorm_extension other_tutor, true
    assert tc.read_by?(main_tutor), "Error: Should be read by main tutor after assess"

    td.destroy!
    unit.destroy!
  end

  def test_auto_grant_for_tutor
    unit = FactoryBot.create(:unit)
    project = unit.projects.first

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Scorm extension request',
        description: 'Scorm extension request',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'ScormExtensionRequest',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: true,
        scorm_attempt_limit: 1
      }
    )
    td.save!

    main_tutor = project.tutor_for(td)
    data_to_post = {
      comment: 'I need more attempts please'
    }

    # Scorm extension request made by tutor
    add_auth_header_for(user: main_tutor)

    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/request_scorm_extension", data_to_post
    assert_equal 201, last_response.status
    assert last_response_body["type"] == "scorm_extension"

    tc = ScormExtensionComment.find(last_response_body["id"])

    # Check if it is granted automatically
    assert tc.read_by?(main_tutor), "Error: Should be read by main tutor after assess"
    assert tc.extension_granted, "Error: Should be granted"

    td.destroy!
    unit.destroy!
  end

  def test_scorm_extension_assessment
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    user = project.student

    td = TaskDefinition.new(
      {
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Scorm extension',
        description: 'Scorm extension',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.week,
        abbreviation: 'ScormExtension',
        restrict_status_updates: false,
        upload_requirements: [],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0,
        scorm_enabled: true,
        scorm_attempt_limit: 2
      }
    )
    td.save!

    main_tutor = project.tutor_for(td)
    task = project.task_for_task_definition(td)
    initial_extension_count = task.scorm_extensions

    tc = task.apply_for_scorm_extension(user, "I need more attempts please")

    data_to_put = {
      granted: true
    }

    add_auth_header_for(user: user)

    # When the user is unauthorised
    put_json "/api/projects/#{project.id}/task_def_id/#{td.id}/assess_scorm_extension/#{tc.id}", data_to_put
    assert_equal 403, last_response.status

    add_auth_header_for(user: main_tutor)

    # Grant extension
    put_json "/api/projects/#{project.id}/task_def_id/#{td.id}/assess_scorm_extension/#{tc.id}", data_to_put
    assert_equal 200, last_response.status

    tc = ScormExtensionComment.find(last_response_body["id"])
    task = project.task_for_task_definition(td)

    # Check scorm extension count
    assert tc.extension_granted, "Error: Should be granted"
    assert tc.assessed?, "Error: Should be assessed"
    assert task.scorm_extensions == initial_extension_count + td.scorm_attempt_limit

    new_extension_count = task.scorm_extensions

    add_auth_header_for(user: main_tutor)

    # Duplicate assessment
    put_json "/api/projects/#{project.id}/task_def_id/#{td.id}/assess_scorm_extension/#{tc.id}", data_to_put
    assert_equal 403, last_response.status

    task = project.task_for_task_definition(td)

    assert task.scorm_extensions == new_extension_count

    td.destroy!
    unit.destroy!
  end
end
