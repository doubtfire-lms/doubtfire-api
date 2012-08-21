class ConvenorContactMailer < ActionMailer::Base

  def request_project_membership(user, convenor, project_template, role)
    user_email = "#{user.username}@swin.edu.au"

    mail to: "ajones@swin.edu.au, rliston@swin.edu.au", 
         from: user_email, 
         subject: "[Doubtfire] Please add #{user.username} to #{project_template.name} as a #{role}", 
         body: "The following user wishes to be added to #{project_template.name} on Doubtfire:\n\nUsername: #{user.username}\nEmail: #{user_email}\nRole: #{role}\n\nYou will also need to ensure their name, surname, and email are present in the system."
  end

end