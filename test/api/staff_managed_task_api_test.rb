require 'test_helper'

class StaffManagedTaskApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_convenor_can_enable_staff_managed_task
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 1)
    task_definition = unit.task_definitions.first

    assert_not task_definition.staff_managed_task

    add_auth_header_for(user: unit.main_convenor_user)
    put_json "/api/units/#{unit.id}/task_definitions/#{task_definition.id}",
             { task_def: { staff_managed_task: true } }

    assert_equal 200, last_response.status, last_response_body
    assert task_definition.reload.staff_managed_task
    assert_equal true, last_response_body['staff_managed_task']
  end

  def test_students_cannot_change_status_or_upload_to_staff_managed_task
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 1)
    task_definition = unit.task_definitions.first
    task_definition.update!(staff_managed_task: true)
    project = unit.active_projects.first
    task = project.task_for_task_definition(task_definition)
    task_url = "/api/projects/#{project.id}/task_def_id/#{task_definition.id}"
    original_status = task.task_status

    add_auth_header_for(user: project.student)
    put task_url, { trigger: 'need_help' }
    assert_equal 403, last_response.status, last_response_body
    assert_equal original_status, task.reload.task_status

    post "#{task_url}/submission", {}
    assert_equal 403, last_response.status, last_response_body
    assert_nil task.reload.file_uploaded_at

    add_auth_header_for(user: unit.main_convenor_user)
    put task_url, { trigger: 'working_on_it' }
    assert_equal 200, last_response.status, last_response_body
    assert_equal TaskStatus.working_on_it, task.reload.task_status

    add_auth_header_for(user: project.student)
    put task_url, { trigger: 'not_started' }
    assert_equal 403, last_response.status, last_response_body
    assert_equal TaskStatus.working_on_it, task.reload.task_status
  end
end
