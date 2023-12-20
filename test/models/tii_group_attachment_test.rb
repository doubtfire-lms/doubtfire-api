require 'test_helper'
require 'tca_client'
require 'json'

class TiiGroupAttachmentTest < ActiveSupport::TestCase
  include TestHelpers::TiiTestHelper
  include TestHelpers::TestFileHelper

  def test_can_get_task_def_tii_group_without_update
    td = FactoryBot.create(:task_definition)

    refute td.tii_group_id.present?

    td.create_or_get_tii_group

    assert td.tii_group_id.present?
  end

  def test_group_attachment_process
    initial_group_attachment_count = TiiGroupAttachment.count
    initial_action_count = TiiActionUploadTaskResources.count

    # Create a task definition
    td = FactoryBot.create(:task_definition)

    td.upload_requirements = [
      {
        "key" => 'file0',
        "name" => 'Document 1',
        "type" => 'document',
        "tii_check" => true,
        "tii_pct" => 35
      }
    ]

    # Save will trigger TII integration
    create_tii_group_stub = stub_request(:put, %r[https://localhost/api/v1/groups/.*]).
    with(tii_headers).
    with(body: %r[.*id.*.*name.*type.*ASSIGNMENT.*group_context.*id.*name.*due_date.*report_generation.*IMMEDIATELY_AND_DUE_DATE.*]).
    to_return(status: 200, body: "", headers: {})

    delete_stub = stub_request(:delete, %r[https://localhost/api/v1/groups/.*/attachments/.*]).
      with(tii_headers).
      to_return(status: 200, body: "", headers: {})

    td.save

    # "Upload" task resources
    FileUtils.cp test_file_path('TaskDefResources.zip'), td.task_resources

    assert td.has_task_resources?

    gaid = SecureRandom.uuid
    req_copy = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/groups/#{td.tii_group_id}/attachments").
    with(tii_headers).
    with(body: "{\"title\":\"TestWordDoc copy.docx\",\"template\":false}").
    to_return(
      status: 200,
      body: TCAClient::AddGroupAttachmentResponse.new(
        id: gaid
      ).to_json,
      headers: {}
    )

    req_first = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/groups/#{td.tii_group_id}/attachments").
    with(tii_headers).
    with(body: "{\"title\":\"TestWordDoc.docx\",\"template\":false}").
    to_return(
      {status: 503, body: "", headers: {}},
      {
        status: 200,
        body: TCAClient::AddGroupAttachmentResponse.new(
          id: SecureRandom.uuid
        ).to_json,
        headers: {}
      }
    )

    upload_stub = stub_request(:put, %r[https://localhost/api/v1/groups/.*/attachments/.*/original]).
      with(tii_headers).
      with(headers: {'Content-Type'=>'binary/octet-stream'}).
      to_return(status: 200, body: '{ "message": "Successfully uploaded file for attachment ..." }', headers: {})

    # Will trigger TII integration - create and send attachments
    # 2 - group attachment for the files and
    # 2 - action objects to track progress
    td.send_group_attachments_to_tii

    # Should trigger the two calls...
    assert_requested req_copy, times: 1
    assert_requested req_first, times: 1

    # We have the details of the attachments
    assert_equal initial_group_attachment_count + 2, TiiGroupAttachment.count, "There should be 2 attachments created"
    assert_equal initial_action_count + 2, TiiActionUploadTaskResources.count, "There should be 2 actions created"

    # One action should have its it... and we have recorded this...
    assert_equal 1, TiiGroupAttachment.where(task_definition: td, group_attachment_id: gaid).count
    assert_equal 1, TiiGroupAttachment.where(task_definition: td, group_attachment_id: nil, status: :created).count

    # Get the group attachment and action objects for the attachment to upload
    ga = TiiGroupAttachment.where(task_definition: td, group_attachment_id: gaid).first
    action = TiiActionUploadTaskResources.where(entity: ga).last

    assert_equal "TestWordDoc copy.docx", ga.filename
    assert_requested upload_stub, times: 1
    assert :complete, action.status_sym

    # Now test failed action
    get_status_stub = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/groups/#{td.tii_group_id}/attachments/#{ga.group_attachment_id}").
      with(tii_headers).
      to_return(
        {
          status: 200,
          body: TCAClient::GroupAttachmentResponse.new(
            id: ga.group_attachment_id,
            status: 'PROCESSING'
          ).to_json,
          headers: {}
        },
        {
          status: 200,
          body: TCAClient::GroupAttachmentResponse.new(
            id: ga.group_attachment_id,
            status: 'COMPLETE'
          ).to_json,
          headers: {}
        },
        {
          status: 200,
          body: TCAClient::GroupAttachmentResponse.new(
            id: ga.group_attachment_id,
            status: 'ERROR',
            error_code: 'TOO_LITTLE_TEXT'
          ).to_json,
          headers: {}
        }
      )

    # Check status
    action.perform

    assert_requested get_status_stub, times: 1
    assert_equal :uploaded, ga.reload.status_sym

    # Check status
    action.perform

    assert_requested get_status_stub, times: 2
    assert_equal :complete, ga.reload.status_sym
    assert action.complete

    # Reset and check status again to test error
    ga.status = :uploaded
    action.complete = false

    ga.save
    action.save

    refute action.reload.complete
    refute_equal :complete, ga.reload.status_sym

    action.perform

    assert_requested get_status_stub, times: 3
    assert action.error_message.include?('TOO_LITTLE_TEXT')
    assert_equal :custom_tii_error, action.error_code.to_sym
    assert action.error?

    td.unit.destroy!

    assert_requested delete_stub, times: 1
    assert_equal initial_group_attachment_count, TiiGroupAttachment.count
  end
end
