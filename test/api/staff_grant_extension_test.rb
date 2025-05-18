require 'test_helper'

class StaffGrantExtensionTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_staff_grant_extension_success
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    staff = FactoryBot.create(:user, role: Role.tutor)
    unit.employ_staff(staff, Role.tutor)

    td = TaskDefinition.new({
      unit_id: unit.id,
      tutorial_stream: unit.tutorial_streams.first,
      name: 'Staff Grant Extension Test',
      description: 'Test task for staff grant extension',
      weighting: 4,
      target_grade: 0,
      start_date: Time.zone.now - 1.week,
      target_date: Time.zone.now + 1.week,
      due_date: Time.zone.now + 2.weeks,
      abbreviation: 'STAFFGRANTTEST',
      restrict_status_updates: false,
      upload_requirements: [],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      max_quality_pts: 0
    })
    td.save!

    data_to_post = {
      student_ids: [project.student.id],
      task_definition_id: td.id,
      weeks_requested: 1,
      comment: 'Staff granted extension'
    }

    add_auth_header_for user: staff
    post_json "/api/units/#{unit.id}/staff-grant-extension", data_to_post
    assert_equal 201, last_response.status

    response = last_response_body
    assert response["successful"].length == 1, 'Should have one successful extension'
    assert response["failed"].empty?, 'Should have no failed extensions'
    assert response["successful"][0]["student_id"] == project.student.id, 'Should match the student ID'
    assert response["successful"][0]["weeks_requested"] == 1, 'Should have requested 1 week'
    assert response["successful"][0]["extension_response"].present?, 'Should have extension response'
    assert response["successful"][0]["task_status"].present?, 'Should have task status'

    notifications = Notification.where(user_id: project.student.id)
    assert_equal 1, notifications.count, 'Should create one notification for the student'
    notification = notifications.first
    assert_match /You were granted an extension for task/, notification.message
    assert_match /#{td.name}/, notification.message
    assert_match /#{unit.name}/, notification.message

    td.destroy!
    unit.destroy!
  end

  def test_staff_grant_extension_unauthorized
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    student = project.student # Using student instead of staff
    td = unit.task_definitions.first

    data_to_post = {
      student_ids: [project.student.id],
      task_definition_id: td.id,
      weeks_requested: 1,
      comment: 'Unauthorized attempt'
    }

    add_auth_header_for user: student
    post_json "/api/units/#{unit.id}/staff-grant-extension", data_to_post
    assert_equal 403, last_response.status, 'Should not allow non-staff to grant extensions'
  end

  def test_staff_grant_extension_invalid_weeks
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    staff = FactoryBot.create(:user, role: Role.tutor)
    unit.employ_staff(staff, Role.tutor)
    td = unit.task_definitions.first

    data_to_post = {
      student_ids: [project.student.id],
      task_definition_id: td.id,
      weeks_requested: 0,
      comment: 'Invalid weeks'
    }

    add_auth_header_for user: staff
    post_json "/api/units/#{unit.id}/staff-grant-extension", data_to_post
    assert_equal 403, last_response.status, 'Should not allow 0 weeks extension'
  end

  def test_staff_grant_extension_negative_weeks
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    staff = FactoryBot.create(:user, role: Role.tutor)
    unit.employ_staff(staff, Role.tutor)
    td = unit.task_definitions.first

    data_to_post = {
      student_ids: [project.student.id],
      task_definition_id: td.id,
      weeks_requested: -1,
      comment: 'Negative weeks'
    }

    add_auth_header_for user: staff
    post_json "/api/units/#{unit.id}/staff-grant-extension", data_to_post
    assert_equal 403, last_response.status, 'Should not allow negative weeks extension'
  end

  def test_staff_grant_extension_missing_params
    unit = FactoryBot.create(:unit)
    staff = FactoryBot.create(:user, role: Role.tutor)
    unit.employ_staff(staff, Role.tutor)

    data_to_post = {
      student_ids: [1],
      # Missing task_definition_id and weeks_requested
      comment: 'Missing params'
    }

    add_auth_header_for user: staff
    post_json "/api/units/#{unit.id}/staff-grant-extension", data_to_post
    assert_equal 400, last_response.status, 'Should require all parameters'
  end

  def test_staff_grant_extension_transaction_rollback
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    staff = FactoryBot.create(:user, role: Role.tutor)
    unit.employ_staff(staff, Role.tutor)
    td = unit.task_definitions.first

    # Test case 1: One valid student, one skipped student
    data_to_post = {
      student_ids: [project.student.id, 999999], # One valid, one invalid
      task_definition_id: td.id,
      weeks_requested: 1,
      comment: 'Transaction test with skipped student'
    }

    add_auth_header_for user: staff
    post_json "/api/units/#{unit.id}/staff-grant-extension", data_to_post
    assert_equal 201, last_response.status, 'Should succeed for valid student'

    response = last_response_body
    assert response["successful"].length == 1, 'Should have one successful extension'
    assert response["skipped"].length == 1, 'Should have one skipped student'
    assert response["failed"].empty?, 'Should have no failed extensions'
    assert response["skipped"][0]["student_id"] == 999999, 'Should have skipped the invalid student ID'
    assert response["skipped"][0]["reason"] == 'Student not found in unit', 'Should have correct skip reason'

    # Verify only the valid student got an extension
    task = project.task_for_task_definition(td)
    assert task.extensions == 1, 'Should have one extension for the valid student'

    # Test case 2: Test actual transaction rollback
    # Create a second project to test with
    project2 = unit.projects.create!(
      user: FactoryBot.create(:user, role: Role.student),
      enrolled: true
    )

    # First, grant extensions to both students
    data_to_post = {
      student_ids: [project.student.id, project2.student.id],
      task_definition_id: td.id,
      weeks_requested: 1,
      comment: 'Initial extensions'
    }

    add_auth_header_for user: staff
    post_json "/api/units/#{unit.id}/staff-grant-extension", data_to_post
    assert_equal 201, last_response.status, 'Should succeed for both students'

    # Verify both students got extensions
    task1 = project.task_for_task_definition(td)
    task2 = project2.task_for_task_definition(td)
    assert task1.extensions == 2, 'First student should have two extensions'
    assert task2.extensions == 1, 'Second student should have one extension'

    # Now try to grant extensions with a task that would cause a failure
    # Use a task that's past its deadline to force a failure
    td.due_date = Time.zone.now - 1.day
    td.save!

    data_to_post = {
      student_ids: [project.student.id, project2.student.id],
      task_definition_id: td.id,
      weeks_requested: 1,
      comment: 'Transaction rollback test'
    }

    add_auth_header_for user: staff
    post_json "/api/units/#{unit.id}/staff-grant-extension", data_to_post
    assert_equal 403, last_response.status, 'Should fail with 403 when task is past deadline'

    # Verify neither student got a new extension (transaction rolled back)
    task1.reload
    task2.reload
    assert task1.extensions == 2, 'First student should still have two extensions'
    assert task2.extensions == 1, 'Second student should still have one extension'

    td.destroy!
    unit.destroy!
  end

  def test_staff_grant_extension_invalid_unit
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    staff = FactoryBot.create(:user, role: Role.tutor)
    unit.employ_staff(staff, Role.tutor)
    td = unit.task_definitions.first

    data_to_post = {
      student_ids: [project.student.id],
      task_definition_id: td.id,
      weeks_requested: 1,
      comment: 'Invalid unit'
    }

    add_auth_header_for user: staff
    post_json "/api/units/999999/staff-grant-extension", data_to_post
    assert_equal 404, last_response.status, 'Should return 404 for invalid unit'
  end

  def test_staff_grant_extension_invalid_task
    unit = FactoryBot.create(:unit)
    project = unit.projects.first
    staff = FactoryBot.create(:user, role: Role.tutor)
    unit.employ_staff(staff, Role.tutor)

    data_to_post = {
      student_ids: [project.student.id],
      task_definition_id: 999999,
      weeks_requested: 1,
      comment: 'Invalid task'
    }

    add_auth_header_for user: staff
    post_json "/api/units/#{unit.id}/staff-grant-extension", data_to_post
    assert_equal 404, last_response.status, 'Should return 404 for invalid task definition'
  end
end
