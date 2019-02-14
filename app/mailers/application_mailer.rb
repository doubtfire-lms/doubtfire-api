class ApplicationMailer < ActionMailer::Base
  default from: 'rsaldhwi@deakin.edu.au'
  layout 'mailer'

  def send_email(user,unit,email)
    @user = user
    @unit = unit
    mail(to: email, subject: 'Unit Request')
  end

end
