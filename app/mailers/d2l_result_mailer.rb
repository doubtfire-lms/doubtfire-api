class D2lResultMailer < ApplicationMailer
  def result_message(unit, user)
    email = user.email
    return nil if email.blank?

    path = D2lIntegration.result_file_path(unit)

    if File.exist?(path)
      attachments['result.csv'] = File.read(path)
    end

    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
    @user = user
    @unit = unit

    mail(to: email, from: email, subject: "#{@doubtfire_product_name} #{unit.code} - D2L Grade Transfer Result")
  end
end
