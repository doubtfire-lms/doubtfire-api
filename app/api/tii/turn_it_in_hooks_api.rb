require 'grape'

module Tii
  class TurnItInHooksApi < Grape::API
    include LogHelper

    desc 'Accept the TurnItIn EULA', {
      headers: {
        "X-Turnitin-Signature" => {
          description: "Valdates server identity",
          required: true
        },
        "X-Turnitin-EventType" => {
          description: "The name of the event type for this request",
          required: true
        }
      }
    }
    post 'tii_hook' do
      data = JSON.parse(env['api.request.input'])
      digest = OpenSSL::Digest.new('sha256')

      # puts data
      hmac = OpenSSL::HMAC.hexdigest(digest, ENV.fetch('TCA_API_KEY', nil), data.to_json)

      # puts hmac
      # puts headers['X-Turnitin-Signature']

      # if hmac != headers["X-Turnitin-Signature"]
      #   logger.error("TII: HMAC does not match")
      #   error!('Signature did not match in webhook request', 401)
      # end

      case headers["X-Turnitin-Eventtype"]
      when 'SUBMISSION_COMPLETE'
        subm = TCAClient::SubmissionCompleteWebhookRequest.new(data)

        instance = TiiSubmission.find_by(submission_id: subm.id)

        instance&.update_from_submission_status(subm)
      when 'SIMILARITY_COMPLETE'
      when 'SIMILARITY_UPDATED'
      when 'PDF_STATUS'
      when 'GROUP_ATTACHMENT_COMPLETE'

      else
        logger.error("TII: unknown event type #{headers['X-Turnitin-EventType']}")
      end
    end
  end
end
