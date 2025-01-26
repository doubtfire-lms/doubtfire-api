# frozen_string_literal: true

require 'yaml'

def receive(_subscriber_instance, channel, _results_publisher, delivery_info, _properties, params)
  params = JSON.parse(params)
  logger.info "Receiving update for overseer assessment: #{params}"
  logger.info "Acknowledge delivery of message"

  # Params must contain:
  # overseer assessment id

  if params['overseer_assessment_id'].nil?
    logger.error 'PARAM `overseer_assessment_id` is required'
    channel.reject(delivery_info.delivery_tag)
    return
  end

  overseer_assessment_id = params['overseer_assessment_id']
  overseer_assessment = OverseerAssessment.find(overseer_assessment_id)

  if overseer_assessment.blank?
    logger.error "No overseer_assessment found for id: #{overseer_assessment_id}"
    channel.reject(delivery_info.delivery_tag)
    return
  end

  channel.ack(delivery_info.delivery_tag)
  overseer_assessment.update_from_output
rescue StandardError => e
  logger.error e.inspect
ensure
  overseer_assessment.save! unless overseer_assessment.nil?
end
