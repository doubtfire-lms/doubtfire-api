namespace :db do
  desc 'Initialise the app with an empty database and only minimal users (the superuser)'
  task demo: [:skip_prod, :environment] do
    require 'populator'
    require 'faker'
    require 'bcrypt'

    # Clear the database
    [Unit, Project, TaskDefinition, Task, TaskStatus, Tutorial, UnitRole, User, ProjectConvenor].each(&:delete_all)

    TaskStatus.create(name:  'Not Started', description: 'You have not yet started this task.')
    TaskStatus.create(name:  'Complete', description: 'This task has been signed off by your tutor.')
    TaskStatus.create(name:  'Need Help', description: 'Some help is required in order to complete this task.')
    TaskStatus.create(name:  'Working On It', description: 'This task is currently being worked on.')
    TaskStatus.create(name:  'Fix and Resubmit', description: 'This task must be resubmitted after fixing some issues.')
    TaskStatus.create(name:  'Do Not Resubmit', description:  'This task must be fixed and included in your portfolio, but should not be resubmitted.')
    TaskStatus.create(name:  'Redo', description: 'This task needs to be redone.')
    TaskStatus.create(name:  'Discuss', description: 'Your work looks good, discuss it with your tutor to complete.')
    TaskStatus.create(name:  'Ready to Mark', description: 'This task is ready for the tutor to assess to provide feedback.')
    TaskStatus.create(name:  'Demonstrate', description: 'Your work looks good, demonstrate it to your tutor to complete.')
    TaskStatus.create(name:  'Fail', description: 'You did not successfully demonstrate the required learning in this task.')

    admins = {
      admin:         { first: 'Admin', last: 'Admin', nickname: 'Superuser' }
    }

    admins.each do |username, info|
      # Create superuser
      User.populate(1) do |superuser|
        superuser.username            = username.to_s
        superuser.nickname            = info[:nickname]
        superuser.email               = "#{username}@swin.edu.au"
        superuser.encrypted_password  = BCrypt::Password.create('demopassword')
        superuser.first_name          = info[:first]
        superuser.last_name           = info[:last]
        superuser.sign_in_count       = 0
        superuser.system_role         = 'superuser'
      end
    end
  end
end
