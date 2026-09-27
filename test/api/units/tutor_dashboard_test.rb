require 'test_helper'

class TutorDashboardTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  setup do
    @unit = FactoryBot.create(
      :unit,
      student_count: 4,
      unenrolled_student_count: 0,
      part_enrolled_student_count: 0,
      inactive_student_count: 0,
      task_count: 1,
      tutorials: 2,
      staff_count: 0
    )
    @unit.update!(
      feedback_warning_threshold_days: 4,
      feedback_overflow_threshold_days: 7
    )

    @convenor_role = @unit.main_convenor
    @tutor_user = FactoryBot.create(:user, :tutor)
    @other_tutor_user = FactoryBot.create(:user, :tutor)
    @tutor_role = @unit.employ_staff(@tutor_user, Role.tutor)
    @other_tutor_role = @unit.employ_staff(@other_tutor_user, Role.tutor)
    @unit.tutorials.first.assign_tutor(@tutor_user)
    @unit.tutorials.second.assign_tutor(@other_tutor_user)

    @task_definition = @unit.task_definitions.first
    @task_definition.update!(target_grade: 0)

    tutor_projects = @unit.tutorials.first.projects.order(:id).to_a
    @overdue_task = tutor_projects.first.task_for_task_definition(@task_definition)
    @warning_task = tutor_projects.second.task_for_task_definition(@task_definition)
    @overdue_task.update!(
      task_status: TaskStatus.ready_for_feedback,
      submission_date: 8.days.ago
    )
    @warning_task.update!(
      task_status: TaskStatus.ready_for_feedback,
      submission_date: 5.days.ago
    )

    @tutor_role.add_tutor_note(@convenor_role.user, 'Please review this feedback.')
  end

  test 'tutor dashboard reports assigned operational workload' do
    add_auth_header_for(user: @tutor_user)

    get "/api/units/#{@unit.id}/tutor_dashboard/#{@tutor_role.id}"

    assert_equal 200, last_response.status, last_response_body
    assert_equal @tutor_role.id, last_response_body.dig('unit_role', 'id')
    assert_equal 2, last_response_body.dig('inbox', 'ready_for_feedback_count')
    assert_equal 1, last_response_body.dig('inbox', 'overdue_count')
    assert_equal 1, last_response_body.dig('inbox', 'age_buckets', 'warning_count')
    assert_equal @overdue_task.id, last_response_body.dig('inbox', 'oldest_tasks', 0, 'id')
    assert_equal 1, last_response_body.dig('tutor_notes', 'unread_by_tutor_count')
    assert_equal false, last_response_body.dig('permissions', 'can_switch_tutor')
    assert_nil last_response_body.dig('moderation', 'pending_count')
  end

  test 'tutor cannot view another tutors dashboard' do
    add_auth_header_for(user: @tutor_user)

    get "/api/units/#{@unit.id}/tutor_dashboard/#{@other_tutor_role.id}"

    assert_equal 403, last_response.status
  end

  test 'convenor can view a tutor dashboard' do
    add_auth_header_for(user: @convenor_role.user)

    get "/api/units/#{@unit.id}/tutor_dashboard/#{@tutor_role.id}"

    assert_equal 200, last_response.status, last_response_body
    assert_equal true, last_response_body.dig('permissions', 'can_switch_tutor')
    assert_equal true, last_response_body.dig('permissions', 'can_view_moderation')
    assert_not_nil last_response_body.dig('moderation', 'pending_count')
  end

  test 'dashboard rejects a unit role from another unit' do
    other_unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 0,
      tutorials: 0,
      staff_count: 0
    )
    add_auth_header_for(user: @convenor_role.user)

    get "/api/units/#{@unit.id}/tutor_dashboard/#{other_unit.main_convenor_id}"

    assert_equal 404, last_response.status
  end
end
