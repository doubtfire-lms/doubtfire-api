class ConvenorContactMailer < ApplicationMailer
  def request_project_membership(user, _convenor, unit, _first_name, _last_name)
    @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]

    institution_email_domain = Doubtfire::Application.config.institution[:email_domain]
    admin_emails = User.admins.map(&:email)
    user_email = "#{user.username}@#{institution_email_domain}"
    mail to: admin_emails,
         from: user_email,
         subject: "[#{@doubtfire_product_name}] Please add #{user.username} to #{unit.name}",
         body: "The following user wishes to be added to #{unit.name} on " \
               "#{@doubtfire_product_name}:\n\nUsername: #{user.username}\nEmail: #{user_email}\n" \
               "Name: #{user.name}"
  end
end
