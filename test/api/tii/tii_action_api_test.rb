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

  def setup
    TiiAction.delete_all

    setup_tii_eula

    # Create a task definition with two attachments
    @task_def = FactoryBot.create(:task_definition,
      unit: FactoryBot.create(:unit, with_students: false, task_count: 0), upload_requirements: [
        {
          'key' => 'file0',
          'name' => 'My document',
          'type' => 'document',
          'tii_check' => 'true',
          'tii_pct' => '10'
        }]
    )

    @unit = @task_def.unit

    ga1 = TiiGroupAttachment.create(
      task_definition: @task_def,
      status: :complete,
      filename: 'test.doc',
      file_sha1_digest: 'digest'
    )
    ga2 = TiiGroupAttachment.create(
      task_definition: @task_def,
      status: :complete,
      filename: 'test1.doc',
      file_sha1_digest: 'digest'
    )

    TiiActionUploadTaskResources.find_or_create_by(entity: ga1)
    TiiActionUploadTaskResources.find_or_create_by(entity: ga2)

    # Accept the eula
    @convenor = @unit.main_convenor_user
    @convenor.accept_tii_eula

    @student = FactoryBot.create(:user, :student)

    @tutor = FactoryBot.create(:user, :tutor)

    @project = @unit.enrol_student(@student, Campus.first)

    @unit.employ_staff(@tutor, Role.tutor)

    @task = @project.task_for_task_definition(@task_def)

    # Create a submission
    sub1 = TiiSubmission.create(
      task: @task,
      idx: 0,
      filename: 'test.doc',
      status: :created,
      submitted_by_user: @convenor
    )

    sub2 = TiiSubmission.create(
      task: @task,
      idx: 1,
      filename: 'test1.doc',
      status: :created,
      submitted_by_user: @convenor
    )

    TiiActionUploadSubmission.find_or_create_by(entity: sub1).inspect
    TiiActionUploadSubmission.find_or_create_by(entity: sub2).inspect
  end

  def teardown
    @unit.destroy!
  end

  def test_get_unit_tii_actions
    add_auth_header_for(user: @convenor)
    get "/api/tii_actions?unit_id=#{@unit.id}"

    assert_equal 200, last_response.status
    assert_equal 4, last_response_body.length, last_response_body

    assert_equal 2, last_response_body.select { |a| a['type'] == 'TiiActionUploadTaskResources' }.length
    assert_equal 2, last_response_body.select { |a| a['type'] == 'TiiActionUploadSubmission' }.length
  end

  def test_get_a_page_of_actions
    add_auth_header_for(user: @convenor)
    get "/api/tii_actions?unit_id=#{@unit.id}&limit=2"

    assert_equal 200, last_response.status
    assert_equal 2, last_response_body.length, last_response_body
    assert_equal 2, last_response_body.select { |a| a['type'] == 'TiiActionUploadSubmission' }.length

    get "/api/tii_actions?unit_id=#{@unit.id}&limit=2&offset=2"
    assert_equal 2, last_response_body.length, last_response_body

    assert_equal 2, last_response_body.select { |a| a['type'] == 'TiiActionUploadTaskResources' }.length
  end

  def test_get_all_tii_actions
    add_auth_header_for(user: User.where(role: Role.admin).first)
    get "/api/tii_actions"

    assert_equal 200, last_response.status
    assert_equal 5, last_response_body.length, last_response_body

    assert_equal 2, last_response_body.select { |a| a['type'] == 'TiiActionUploadTaskResources' }.length
    assert_equal 2, last_response_body.select { |a| a['type'] == 'TiiActionUploadSubmission' }.length
    assert_equal 1, last_response_body.select { |a| a['type'] == 'TiiActionAcceptEula' }.length
  end

  def test_ensure_access_to_get_actions
    add_auth_header_for(user: @convenor)
    get "/api/tii_actions"

    assert_equal 403, last_response.status

    add_auth_header_for(user: @tutor)
    get "/api/tii_actions"

    assert_equal 403, last_response.status

    add_auth_header_for(user: @student)
    get "/api/tii_actions"

    assert_equal 403, last_response.status

    add_auth_header_for(user: @tutor)
    get "/api/tii_actions?unit_id=#{@unit.id}"

    assert_equal 403, last_response.status

    add_auth_header_for(user: @student)
    get "/api/tii_actions?unit_id=#{@unit.id}"

    assert_equal 403, last_response.status
  end

  def test_trigger_action_via_put
    TiiActionJob.clear
    add_auth_header_for(user: User.where(role: Role.admin).first)
    action = TiiActionUploadSubmission.last
    put_json "/api/tii_actions/#{action.id}", { 'action': 'retry' }

    assert_equal 200, last_response.status
    assert_equal 1, TiiActionJob.jobs.size
    assert_equal action.id, TiiActionJob.jobs.first['args'].first
    TiiActionJob.clear
  end

  def test_trigger_action_via_put_multiple
    TiiActionJob.clear
    add_auth_header_for(user: User.where(role: Role.admin).first)
    action = TiiActionUploadSubmission.last

    put_json "/api/tii_actions/#{action.id}", { 'action': 'retry' }
    assert_equal 200, last_response.status

    put_json "/api/tii_actions/#{action.id}", { 'action': 'retry' }
    assert_equal 403, last_response.status

    assert_equal 1, TiiActionJob.jobs.size
    assert_equal action.id, TiiActionJob.jobs.first['args'].first
    TiiActionJob.clear
  end
end
