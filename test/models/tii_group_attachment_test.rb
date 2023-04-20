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
    # Create a task definition
    td = FactoryBot.create(:task_definition)

    # "Upload" task resources
    FileUtils.cp test_file_path('TaskDefResources.zip'), td.task_resources

    assert td.has_task_resources?

    gaid = SecureRandom.uuid
    req_copy = stub_request(:post, "https://localhost/api/v1/groups/#{td.tii_group_id}/attachments").
    with(tii_headers).
    with(body: "{\"title\":\"TestWordDoc copy.docx\",\"template\":false}").
    to_return(
      status: 200,
      body: TCAClient::AddGroupAttachmentResponse.new(
        id: gaid
      ).to_json,
      headers: {}
    )

    req_first = stub_request(:post, "https://localhost/api/v1/groups/#{td.tii_group_id}/attachments").
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

    TurnItIn.send_group_attachments_to_tii(td)

    assert_requested req_copy, times: 1
    assert_requested req_first, times: 1

    assert_equal 1, TiiGroupAttachment.where(task_definition: td, status: :has_id, group_attachment_id: gaid).count
    assert_equal 1, TiiGroupAttachment.where(task_definition: td, status: :has_id).count
    assert_equal 1, TiiGroupAttachment.where(task_definition: td, status: :created, group_attachment_id: nil).count

    ga = TiiGroupAttachment.where(task_definition: td, status: :created).first
    assert_equal "TestWordDoc.docx", ga.filename
    assert_equal 1, ga.retries

    upload_stub = stub_request(:put, %r[.*]).
      with(tii_headers).
      with(headers: {'Content-Type'=>'binary/octet-stream'}).
      with(body: %r[.*]).
      to_return(status: 200, body: '{ "message": "Successfully uploaded file for attachment ..." }', headers: {})

    # Get id and upload attachment
    ga.continue_process
    assert_equal :uploaded, ga.reload.status_sym
    assert_equal 0, ga.retries
    assert_requested upload_stub, times: 1

    get_status_stub = stub_request(:get, "https://localhost/api/v1/groups/#{td.tii_group_id}/attachments/#{ga.group_attachment_id}").
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
    ga.continue_process

    assert_requested get_status_stub, times: 1
    assert_equal :uploaded, ga.reload.status_sym

    # Check status
    ga.continue_process

    assert_requested get_status_stub, times: 2
    assert_equal :complete, ga.reload.status_sym

    # Check status
    ga.update_from_attachment_status(ga.fetch_tii_attachment_status)

    assert_requested get_status_stub, times: 3
    assert_equal 'TOO_LITTLE_TEXT', ga.error_message
    assert_equal :custom_tii_error, ga.error_code.to_sym
    assert ga.error?

    delete_stub = stub_request(:delete, %r[.*]).
    with(tii_headers).
    to_return(status: 200, body: "", headers: {})

    td.unit.destroy!

    assert_requested delete_stub, times: 2
  end
end
