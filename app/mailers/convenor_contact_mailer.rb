class ConvenorContactMailer < ActionMailer::Base

  def request_project_membership(user, convenor, unit, first_name, last_name)
    user_email = "#{user.username}@swin.edu.au"

    mail to: "ajones@swin.edu.au, rliston@swin.edu.au", 
         from: user_email, 
         subject: "[Doubtfire] Please add #{user.username} to #{unit.name}", 
         body: "The following user wishes to be added to #{unit.name} on Doubtfire:\n\nUsername: #{user.username}\nEmail: #{user_email}\nName: #{first_name} #{last_name}"
  end

end