class ErrorLogMailer < ApplicationMailer
  def error_message(subject, message, exception)
    email = Doubtfire::Application.config.email_errors_to
    return nil if email.blank?

    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @error_log = "#{message}\n\n#{exception.message}\n\n#{exception.backtrace.join("\n")}"

    mail(to: email, from: email, subject: "#{@doubtfire_product_name} Error Log - #{subject}")
  end
end
