# frozen_string_literal: true

require 'test_helper'

class TiiGroupAttachmentApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::TiiTestHelper
  include TestHelpers::TestFileHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  setup do
    @task_def = FactoryBot.create(:task_definition,
      unit: FactoryBot.create(:unit, with_students: false, task_count: 0)
    )

    @unit = @task_def.unit

    TiiGroupAttachment.create(
      task_definition: @task_def,
      status: :complete,
      filename: 'test.doc',
      file_sha1_digest: 'digest'
    )
    TiiGroupAttachment.create(
      task_definition: @task_def,
      status: :complete,
      filename: 'test1.doc',
      file_sha1_digest: 'digest'
    )
  end

  def test_only_main_convenor_can_access_group_attachments_for_task_definition
    tutor = FactoryBot.create(:user, :tutor)
    @unit.employ_staff tutor, Role.tutor

    assert_equal Role.tutor, @unit.role_for(tutor)

    add_auth_header_for(user: tutor)

    get "/api/units/#{@unit.id}/task_definitions/#{@task_def.id}/tii_group_attachments"
    assert_equal 403, last_response.status, last_response_body

    put_json "/api/units/#{@unit.id}/task_definitions/#{@task_def.id}/tii_group_attachments/#{@task_def.tii_group_attachments.first.id}", {
      action: 'upload'
    }
    assert_equal 403, last_response.status, last_response_body

    delete "/api/units/#{@unit.id}/task_definitions/#{@task_def.id}/tii_group_attachments/#{@task_def.tii_group_attachments.first.id}"
    assert_equal 403, last_response.status, last_response_body

    # Students cannot access these either...
    student = FactoryBot.create(:user, :student)
    @unit.enrol_student student, Campus.first

    assert_equal Role.student, @unit.role_for(student)

    add_auth_header_for(user: student)

    get "/api/units/#{@unit.id}/task_definitions/#{@task_def.id}/tii_group_attachments"
    assert_equal 403, last_response.status, last_response_body

    put_json "/api/units/#{@unit.id}/task_definitions/#{@task_def.id}/tii_group_attachments/#{@task_def.tii_group_attachments.first.id}", {
      action: 'upload'
    }
    assert_equal 403, last_response.status, last_response_body

    delete "/api/units/#{@unit.id}/task_definitions/#{@task_def.id}/tii_group_attachments/#{@task_def.tii_group_attachments.first.id}"
    assert_equal 403, last_response.status, last_response_body
  end

  def test_can_get_group_attachments_for_task_definition
    # Add auth_token and username to header
    add_auth_header_for(user: @unit.main_convenor_user)

    get "/api/units/#{@unit.id}/task_definitions/#{@task_def.id}/tii_group_attachments"
    assert_equal 200, last_response.status, last_response_body
    assert_equal 2, last_response_body.length
    assert_json_limit_keys_to_exactly(%w(id group_attachment_id filename status), last_response_body.first)
  end

  def test_can_trigger_upload_group_attachments_for_task_definition
    TiiActionJob.jobs.clear

    # Add auth_token and username to header
    add_auth_header_for(user: @unit.main_convenor_user)

    start_count = TiiActionUploadTaskResources.count

    # When we ask to upload the group attachments
    put_json "/api/units/#{@unit.id}/task_definitions/#{@task_def.id}/tii_group_attachments/#{@task_def.tii_group_attachments.first.id}", {
      action: 'upload'
    }

    # It should create a TiiActionUploadTaskResources, and process this async
    assert_equal 200, last_response.status, last_response_body

    assert_equal start_count + 1, TiiActionUploadTaskResources.count
    assert_equal 1, TiiActionJob.jobs.size
    TiiActionJob.jobs.clear
  end

  def test_can_trigger_delete_group_attachments_for_task_definition
    # Add auth_token and username to header
    add_auth_header_for(user: @unit.main_convenor_user)

    # When we ask to upload the group attachments
    delete "/api/units/#{@unit.id}/task_definitions/#{@task_def.id}/tii_group_attachments/#{@task_def.tii_group_attachments.first.id}"

    # It should create a TiiActionUploadTaskResources, and process this async
    assert_equal 200, last_response.status, last_response_body

    assert_equal 1, @task_def.reload.tii_group_attachments.count
    # No group attachment id - so no tii call... but tested elsewhere
  end
end
