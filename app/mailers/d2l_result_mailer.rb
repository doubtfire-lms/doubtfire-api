class D2lResultMailer < ApplicationMailer
  def result_message(unit, user, result_message = 'completed', success = true)
    email = user.email
    return nil if email.blank?

    path = D2lIntegration.result_file_path(unit)

    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @user = user
    @unit = unit
    @result_message = result_message
    @has_file = success && File.exist?(path)

    if @has_file
      attachments['result.csv'] = File.read(path)
    end

    mail(to: email, from: email, subject: "#{@doubtfire_product_name} #{unit.code} - D2L Grade Transfer Result")
  end
end
