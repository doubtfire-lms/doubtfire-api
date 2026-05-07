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

  def action_log_email(to:, from:, subject:, body:, recipient:, sender:, unit:, rule:, csv_content:, csv_filename:, affected_students_count:)
    @recipient = recipient
    @sender = sender
    @unit = unit
    @rule = rule
    @body = body.to_s
    @body_paragraphs = @body.split(/\r?\n/).map(&:strip).reject(&:blank?)
    @affected_students_count = affected_students_count

    @doubtfire_host = Doubtfire::Application.config.institution[:host]
    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @unsubscribe_url = "#{@doubtfire_host}/edit_profile"

    attachments[csv_filename] = {
      mime_type: 'text/csv',
      content: csv_content
    }

    mail(to: to, from: from, subject: subject)
  end
end
