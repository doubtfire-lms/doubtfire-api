namespace :db do
  desc "Initialise the app with an empty database and only minimal users (the superuser)"
  task :demo => :environment do
    require 'populator'
    require 'faker'
    require 'bcrypt'

    # Clear the database
    [ProjectTemplate, Project, TaskTemplate, Task, TaskStatus, Team, TeamMembership, User, ProjectConvenor].each(&:delete_all)

    TaskStatus.create(:name => "Not Submitted", :description => "This task has not been submitted to marked by your tutor.")
    TaskStatus.create(:name => "Complete", :description => "This task has been signed off by your tutor.")
    TaskStatus.create(:name => "Need Help", :description => "Some help is required in order to complete this task.")
    TaskStatus.create(:name => "Working On It", :description => "This task is currently being worked on.")
    TaskStatus.create(:name => "Fix and Resubmit", :description => "This task must be resubmitted after fixing some issues.")
    TaskStatus.create(:name => "Fix and Include", :description => "This task must be fixed and included in your portfolio, but should not be resubmitted.")
    TaskStatus.create(:name => "Redo", :description => "This task needs to be redone.")

    admins = {
      admin:         {first: "Admin",   last: "Admin",   nickname: "Superuser"}
    }

    admins.each do |username, info|
      # Create superuser
      User.populate(1) do |superuser|
        superuser.username            = username.to_s
        superuser.nickname            = info[:nickname]
        superuser.email               = "#{username.to_s}@swin.edu.au"
        superuser.encrypted_password  = BCrypt::Password.create("demopassword")
        superuser.first_name          = info[:first]
        superuser.last_name           = info[:last]
        superuser.sign_in_count       = 0
        superuser.system_role         = "superuser"
      end
    end
    
  end
end