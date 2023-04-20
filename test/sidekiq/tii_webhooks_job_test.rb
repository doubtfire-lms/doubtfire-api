# frozen_string_literal: true

require 'test_helper'
class TiiCWebhooksJobTest < ActiveSupport::TestCase
  include TestHelpers::TiiTestHelper

  def test_register_webhooks
    # Will ask for current webhooks
    list_webhooks_stub = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/webhooks").
    with(tii_headers).
    to_return(
      status: 200,
      body: [
        TCAClient::Webhook.new(
          "id" => "f5d62573-277d-4725-b557-c64877ddf6c7",
          "url" => "https://myschool.sweetlms.com/turnitin-callbacks",
          "description" => "my first webhook",
          "created_time" => "2017-10-20T13:39:53.816Z",
          "event_types" => [
            "SUBMISSION_COMPLETE"
          ]
        ),
        TCAClient::Webhook.new(
          "id" => "another-id",
          "url" => "https://another-url.com",
          "description" => "my second webhook",
          "created_time" => "2017-10-20T13:39:53.816Z",
          "event_types" => [
            "SUBMISSION_COMPLETE"
          ]
        )
      ].to_json,
      headers: {})

    # and will register the webhooks
    register_webhooks_stub = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/webhooks").
    with(tii_headers).
    with(
      body: TCAClient::WebhookWithSecret.new(
        signing_secret: ENV.fetch('TCA_SIGNING_KEY', nil),
        url: TurnItIn.webhook_url,
        event_types: [
          'SIMILARITY_COMPLETE',
          'SUBMISSION_COMPLETE',
          'SIMILARITY_UPDATED',
          'PDF_STATUS',
          'GROUP_ATTACHMENT_COMPLETE'
        ]
      ).to_json,
    ).
    to_return(status: 200, body: "", headers: {})

    job = TiiRegisterWebHookJob.new
    job.perform

    assert_requested list_webhooks_stub, times: 1
    assert_requested register_webhooks_stub, times: 1
  end

  def test_do_not_register_if_registered
    # Will ask for current webhooks
    list_webhooks_stub = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/webhooks").
    with(tii_headers).
    to_return(
      status: 200,
      body: [
        TCAClient::Webhook.new(
          "id" => "f5d62573-277d-4725-b557-c64877ddf6c7",
          "url" => "https://myschool.sweetlms.com/turnitin-callbacks",
          "description" => "my first webhook",
          "created_time" => "2017-10-20T13:39:53.816Z",
          "event_types" => [
            "SUBMISSION_COMPLETE"
          ]
        ),
        TCAClient::Webhook.new(
          "id" => "another-id",
          "url" => TurnItIn.webhook_url,
          "description" => "my second webhook",
          "created_time" => "2017-10-20T13:39:53.816Z",
          "event_types" => [
            "SUBMISSION_COMPLETE"
          ]
        )
      ].to_json,
      headers: {})

    # and will register the webhooks
    register_webhooks_stub = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/webhooks").
    with(tii_headers).
    with(
      body: TCAClient::WebhookWithSecret.new(
        signing_secret: ENV.fetch('TCA_SIGNING_KEY', nil),
        url: TurnItIn.webhook_url,
        event_types: [
          'SIMILARITY_COMPLETE',
          'SUBMISSION_COMPLETE',
          'SIMILARITY_UPDATED',
          'PDF_STATUS',
          'GROUP_ATTACHMENT_COMPLETE'
        ]
      ).to_json,
    ).
    to_return(status: 200, body: "", headers: {})

    job = TiiRegisterWebHookJob.new
    job.perform

    assert_requested list_webhooks_stub, times: 1
    assert_requested register_webhooks_stub, times: 0
  end
end
