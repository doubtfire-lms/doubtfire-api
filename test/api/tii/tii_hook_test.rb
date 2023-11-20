# frozen_string_literal: true

require 'test_helper'

class TeachingPeriodTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::TiiTestHelper
  include TestHelpers::TestFileHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # Test the submission webhook
  def test_submission_webhook
    setup_tii_features_enabled

    task = FactoryBot.create(:task)
    user = task.project.user

    subm = TiiSubmission.create!(
      submission_id: "e884f478-9757-41c7-80da-37b94ebb2838",
      status: 'uploaded',
      task: task,
      idx: 0,
      filename: 'test.doc',
      submitted_at: Time.zone.now,
      submitted_by: task.project.user
    )

    # destroy will trigger delete of submission
    delete_request = stub_request(:delete, /https:\/\/#{ENV['TCA_HOST']}\/api\/v1\/submissions\/e884f478-9757-41c7-80da-37b94ebb2838/).
    with(tii_headers).
    to_return(status: 200, body: "", headers: {})

    data = TCAClient::SubmissionCompleteWebhookRequest.new(
      "id" => "e884f478-9757-41c7-80da-37b94ebb2838",
      "owner" => "a9c14691-9523-4f44-b5fc-4a673c5d4a35",
      "title" => "History 101 Final Esssay",
      "status" => "COMPLETE",
      "content_type" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "page_count" => 3,
      "word_count" => 145,
      "character_count" => 760,
      "created_time" => "2017-08-30T22:13:41Z",
      "capabilities" => [
          "INDEX",
          "VIEWER",
          "SIMILARITY"
      ],
      "metadata" => {
        "custom" => "{\"Type\":\"Final Paper\"}"
      }
    )

    # puts data.to_json

    digest = OpenSSL::Digest.new('sha256')
    hmac = OpenSSL::HMAC.hexdigest(digest, ENV.fetch('TCA_SIGNING_KEY', nil), data.to_json)

    # Add signature details
    header "X-Turnitin-Signature", hmac
    header "X-Turnitin-EventType", "SUBMISSION_COMPLETE"

    # Callback will trigger similarity request
    stub_request(:put, "https://#{ENV['TCA_HOST']}/api/v1/submissions/e884f478-9757-41c7-80da-37b94ebb2838/similarity").
    with(tii_headers).
    to_return(
      { status: 200, body: TCAClient::SimilarityMetadata.new(status: 'PROCESSING').to_hash.to_json, headers: {}},
    )

    post_json '/api/tii_hook', data

    assert_equal 201, last_response.status, last_response_body
    assert_equal :similarity_report_requested, subm.reload.status_sym

    task.unit.destroy!
  end

  # Test the similarity webhook
  def test_similarity_webhook
    task = FactoryBot.create(:task)
    user = task.project.user

    task.task_definition.upload_requirements = [
      {
        "key" => 'file0',
        "name" => 'Document 1',
        "type" => 'document',
        "tii_check" => true,
        "tii_pct" => 35
      }
    ]

    subm = TiiSubmission.create!(
      submission_id: "e884f478-9757-41c7-80da-37b94ebb2838",
      status: 'similarity_report_requested',
      task: task,
      filename: 'test.doc',
      idx: 0,
      submitted_at: Time.zone.now,
      submitted_by: task.project.user
    )

    # destroy will trigger delete of submission
    delete_request = stub_request(:delete, /https:\/\/#{ENV['TCA_HOST']}\/api\/v1\/submissions\/e884f478-9757-41c7-80da-37b94ebb2838/).
    with(tii_headers).
    to_return(status: 200, body: "", headers: {})

    data = TCAClient::SimilarityCompleteWebhookRequest.new(
      "submission_id" => "e884f478-9757-41c7-80da-37b94ebb2838",
      "overall_match_percentage" => 15,
      "internet_match_percentage" => 12,
      "publication_match_percentage" => 10,
      "submitted_works_match_percentage" => 0,
      "status" => "COMPLETE",
      "time_requested" => "2017-11-06T19:14:31.828Z",
      "time_generated" => "2017-11-06T19:14:45.993Z",
      "top_source_largest_matched_word_count" => 193,
      "top_matches" => [
        {
          "percentage" => 100.0,
          "submission_id" => "883fbb3a-2825-4a2a-8d24-d52e40673772",
          "source_type" => "SUBMITTED_WORK",
          "matched_word_count_total" => 598,
          "submitted_date" => "2021-05-05",
          "institution_name" => "Tii Auto TCA Platinum Test Tenant",
          "name" => "Tii Auto TCA Platinum Test Tenant on 2021-05-05"
        }
      ],
      "metadata" => {
        "custom" => "{\"Type\":\"Final Paper\"}"
      }
    )

    # puts data.to_json

    digest = OpenSSL::Digest.new('sha256')
    hmac = OpenSSL::HMAC.hexdigest(digest, ENV.fetch('TCA_SIGNING_KEY', nil), data.to_json)

    # Add signature details
    header "X-Turnitin-Signature", hmac
    header "X-Turnitin-EventType", "SIMILARITY_COMPLETE"

    post_json '/api/tii_hook', data

    assert_equal 201, last_response.status, last_response_body
    assert_equal :complete_low_similarity, subm.reload.status_sym

    task.unit.destroy!
  end

  # Test the similarity webhook
  def test_similarity_webhook
    task = FactoryBot.create(:task)
    user = task.project.user

    task.task_definition.upload_requirements = [
      {
        "key" => 'file0',
        "name" => 'Document 1',
        "type" => 'document',
        "tii_check" => true,
        "tii_pct" => 35
      }
    ]

    subm = TiiSubmission.create!(
      submission_id: "e884f478-9757-41c7-80da-37b94ebb2838",
      status: 'similarity_report_requested',
      task: task,
      filename: 'test.doc',
      idx: 0,
      submitted_at: Time.zone.now,
      submitted_by: task.project.user
    )

    # destroy will trigger delete of submission
    delete_request = stub_request(:delete, /https:\/\/#{ENV['TCA_HOST']}\/api\/v1\/submissions\/e884f478-9757-41c7-80da-37b94ebb2838/).
    with(tii_headers).
    to_return(status: 200, body: "", headers: {})

    data = TCAClient::SimilarityCompleteWebhookRequest.new(
      "submission_id" => "e884f478-9757-41c7-80da-37b94ebb2838",
      "overall_match_percentage" => 15,
      "internet_match_percentage" => 12,
      "publication_match_percentage" => 10,
      "submitted_works_match_percentage" => 0,
      "status" => "COMPLETE",
      "time_requested" => "2017-11-06T19:14:31.828Z",
      "time_generated" => "2017-11-06T19:14:45.993Z",
      "top_source_largest_matched_word_count" => 193,
      "top_matches" => [
        {
          "percentage" => 100.0,
          "submission_id" => "883fbb3a-2825-4a2a-8d24-d52e40673772",
          "source_type" => "SUBMITTED_WORK",
          "matched_word_count_total" => 598,
          "submitted_date" => "2021-05-05",
          "institution_name" => "Tii Auto TCA Platinum Test Tenant",
          "name" => "Tii Auto TCA Platinum Test Tenant on 2021-05-05"
        }
      ],
      "metadata" => {
        "custom" => "{\"Type\":\"Final Paper\"}"
      }
    )

    # puts data.to_json

    digest = OpenSSL::Digest.new('sha256')
    hmac = OpenSSL::HMAC.hexdigest(digest, ENV.fetch('TCA_SIGNING_KEY', nil), data.to_json)

    # Add signature details
    header "X-Turnitin-Signature", hmac
    header "X-Turnitin-EventType", "SIMILARITY_COMPLETE"

    post_json '/api/tii_hook', data

    assert_equal 201, last_response.status, last_response_body
    assert_equal :complete_low_similarity, subm.reload.status_sym

    task.unit.destroy!
  end

  def test_pdf_status_webhook
    task = FactoryBot.create(:task)
    user = task.project.user

    task.task_definition.upload_requirements = [
      {
        "key" => 'file0',
        "name" => 'Document 1',
        "type" => 'document',
        "tii_check" => true,
        "tii_pct" => 35
      }
    ]

    subm = TiiSubmission.create!(
      submission_id: "e884f478-9757-41c7-80da-37b94ebb2838",
      similarity_pdf_id: "123312",
      status: 'similarity_report_requested',
      task: task,
      filename: 'test.doc',
      idx: 0,
      submitted_at: Time.zone.now,
      submitted_by: task.project.user
    )

    # destroy will trigger delete of submission
    delete_request = stub_request(:delete, /https:\/\/#{ENV['TCA_HOST']}\/api\/v1\/submissions\/e884f478-9757-41c7-80da-37b94ebb2838/).
    with(tii_headers).
    to_return(status: 200, body: "", headers: {})

    data = TCAClient::PDFStatusWebhookRequest.new(
      "status" => "SUCCESS",
      "id" => "e884f478-9757-41c7-80da-37b94ebb2838",
      "submission_id" => "123312",
      "metadata" => {
        "custom" => "{\"Type\":\"Final Paper\"}"
      }
    )

    download_pdf_request = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/submissions/e884f478-9757-41c7-80da-37b94ebb2838/similarity/pdf/123312").
      with(tii_headers).
      to_return(status: 200, body: File.read(test_file_path('submissions/1.2P.pdf')), headers: {})

    # puts data.to_json

    digest = OpenSSL::Digest.new('sha256')
    hmac = OpenSSL::HMAC.hexdigest(digest, ENV.fetch('TCA_SIGNING_KEY', nil), data.to_json)

    # Add signature details
    header "X-Turnitin-Signature", hmac
    header "X-Turnitin-EventType", "PDF_STATUS"

    post_json '/api/tii_hook', data

    assert_equal 201, last_response.status, last_response_body
    assert_equal :similarity_pdf_downloaded, subm.reload.status_sym

    assert_requested download_pdf_request, times: 1
    assert File.exist?(subm.similarity_pdf_path)

    task.unit.destroy!
    refute File.exist?(subm.similarity_pdf_path)
  end

  # Test the group_attachment webhook
  def test_group_attachment_webhook
    td = FactoryBot.create(:task_definition)
    user = td.unit.main_convenor_user

    td.create_or_get_tii_group

    grp_attachment = TiiGroupAttachment.create(
      task_definition: td,
      filename: 'TestWordDoc.docx',
      status: :created,
      file_sha1_digest: 'test'
    )

    grp_attachment.update(group_attachment_id: "16c45fbe-25f5-458b-9a4c-c3deeaff8af4")

    delete_stub = stub_request(:delete, %r[https://#{ENV['TCA_HOST']}/api/v1/groups/#{td.tii_group_id}/attachments/.*]).
      with(tii_headers).
      to_return(status: 200, body: "", headers: {})

    data = TCAClient::GroupAttachmentResponse.new(
        "id": grp_attachment.group_attachment_id,
        "title": "large2",
        "status": "COMPLETE",
        "template": true
    )

    # puts data.to_json

    digest = OpenSSL::Digest.new('sha256')
    hmac = OpenSSL::HMAC.hexdigest(digest, ENV.fetch('TCA_SIGNING_KEY', nil), data.to_json)

    # Add signature details
    header "X-Turnitin-Signature", hmac
    header "X-Turnitin-EventType", "GROUP_ATTACHMENT_COMPLETE"

    post_json '/api/tii_hook', data

    assert_equal 201, last_response.status, last_response_body
    assert_equal :complete, grp_attachment.reload.status_sym

    td.unit.destroy!

    assert_requested delete_stub, times: 1
  end

end
