class ConvenorContactMailer < ActionMailer::Base

  def request_project_membership(user, convenor, project_template, role)
    mail to: "#{convenor.email}", 
         from: "#{user.email}", 
         subject: "Please add me to #{project_template.name} as a #{role}", 
         body: "Dear #{convenor.first_name},\n\nThe following user wishes to be added to #{project_template.name} on Doubtfire:\n\nUsername: #{user.username}\nEmail: #{user.email}\nRole: #{role}"
  end

end
