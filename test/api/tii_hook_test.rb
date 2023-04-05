# frozen_string_literal: true

require 'test_helper'

class TeachingPeriodTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::TiiTestHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # Test the submission webhook
  def test_submission_webhook
    task = FactoryBot.create(:task)
    user = task.project.user

    subm = TiiSubmission.create!(
      submission_id: "e884f478-9757-41c7-80da-37b94ebb2838",
      status: 'uploaded',
      task: task,
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
    hmac = OpenSSL::HMAC.hexdigest(digest, ENV.fetch('TCA_API_KEY', nil), data.to_json)

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
end
