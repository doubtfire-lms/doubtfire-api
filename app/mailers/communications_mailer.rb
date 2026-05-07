class CommunicationsMailer < ApplicationMailer
  def communication_email(to:, from:, subject:, body:, recipient:, sender:, unit:, rule:)
    @recipient = recipient
    @sender = sender
    @unit = unit
    @rule = rule
    @body = body.to_s
    @body_paragraphs = @body.split(/\r?\n/).map(&:strip).reject(&:blank?)

    @doubtfire_host = Doubtfire::Application.config.institution[:host]
    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @unsubscribe_url = "#{@doubtfire_host}/edit_profile"

    mail(to: to, from: from, subject: subject)
  end

  def action_log_email(payload)
    @recipient = payload[:recipient]
    @sender = payload[:sender]
    @unit = payload[:unit]
    @rule = payload[:rule]
    @body = payload[:body].to_s
    @body_paragraphs = @body.split(/\r?\n/).map(&:strip).reject(&:blank?)
    @affected_students_count = payload[:affected_students_count]

    @doubtfire_host = Doubtfire::Application.config.institution[:host]
    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @unsubscribe_url = "#{@doubtfire_host}/edit_profile"

    attachments[payload[:csv_filename]] = {
      mime_type: 'text/csv',
      content: payload[:csv_content]
    }

    mail(to: payload[:to], from: payload[:from], subject: payload[:subject])
  end
end
