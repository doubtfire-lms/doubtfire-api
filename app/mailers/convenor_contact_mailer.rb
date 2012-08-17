class ConvenorContactMailer < ActionMailer::Base

  def request_project_membership(user, convenor, project_template, role)
    user_email = "#{user.username}@swin.edu.au"

    mail to: "#{convenor.email}", 
         from: user_email, 
         subject: "Please add #{user.username} to #{project_template.name} as a #{role}", 
         body: "Dear #{convenor.first_name},\n\nThe following user wishes to be added to #{project_template.name} on Doubtfire:\n\nUsername: #{user.username}\nEmail: #{user_email}\nRole: #{role}\n\nYou will also need to ensure their name, surname, and email are present in the system."
  end

end
