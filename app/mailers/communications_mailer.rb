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
end
