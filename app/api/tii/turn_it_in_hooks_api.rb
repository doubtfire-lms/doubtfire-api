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
      raw_data = env['api.request.input']
      data = JSON.parse(raw_data)
      digest = OpenSSL::Digest.new('sha256')

      logger.debug("TII_HOOK_DEBUG:#{raw_data}")
      hmac = OpenSSL::HMAC.hexdigest(digest, ENV.fetch('TCA_SIGNING_KEY', nil), raw_data)

      logger.debug("TII_HOOK_DEBUG:#{hmac}")
      logger.debug("TII_HOOK_DEBUG:#{headers['x-turnitin-signature']}")

      if hmac != headers["x-turnitin-signature"]
        logger.error("TII: HMAC does not match")
        error!('Signature did not match in webhook request', 401)
      end

      case headers["x-turnitin-eventtype"]
      when 'SUBMISSION_COMPLETE'
        subm = TCAClient::SubmissionCompleteWebhookRequest.new(data)

        instance = TiiSubmission.find_by(submission_id: subm.id)
        action = TiiActionUploadSubmission.find_or_create_by(entity: instance) unless instance.nil?

        action&.update_from_submission_status(subm)
      when 'SIMILARITY_COMPLETE', 'SIMILARITY_UPDATED'
        siml = TCAClient::SimilarityCompleteWebhookRequest.new(data)

        instance = TiiSubmission.find_by(submission_id: siml.submission_id)
        action = TiiActionUploadSubmission.find_or_create_by(entity: instance) unless instance.nil?

        action&.update_from_similarity_status(siml)
      when 'PDF_STATUS'
        req = TCAClient::PDFStatusWebhookRequest.new(data)

        instance = TiiSubmission.find_by(submission_id: req.id)
        action = TiiActionUploadSubmission.find_or_create_by(entity: instance) unless instance.nil?

        action&.update_from_pdf_report_status(req.status)
      when 'GROUP_ATTACHMENT_COMPLETE'
        req = TCAClient::GroupAttachmentResponse.new(data)

        instance = TiiGroupAttachment.find_by(group_attachment_id: req.id)
        action = TiiActionUploadTaskResources.find_or_create_by(entity: instance) unless instance.nil?

        action&.update_from_attachment_status(req)
      else
        logger.error("TII: unknown event type #{headers['X-Turnitin-EventType']}")
      end
    end
  end
end
