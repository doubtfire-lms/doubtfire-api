namespace :db do
  desc "Initialise the app with an empty database and only minimal users (the superuser)"
  task init:  :environment do
    require 'populator'
    require 'faker'
    require 'bcrypt'

    # Clear the database
    [Unit, Project, TaskDefinition, Task, TaskStatus, Tutorial, UnitRole, User, Role, TaskEngagement, TaskSubmission].each(&:delete_all)

    TaskStatus.create(name:  "Not Started", description:  "You have not yet started this task.")
    TaskStatus.create(name:  "Complete", description:  "This task has been signed off by your tutor.")
    TaskStatus.create(name:  "Need Help", description:  "Some help is required in order to complete this task.")
    TaskStatus.create(name:  "Working On It", description:  "This task is currently being worked on.")
    TaskStatus.create(name:  "Fix and Resubmit", description:  "This task must be resubmitted after fixing some issues.")
    TaskStatus.create(name:  "Do Not Resubmit", description:  "This task must be fixed and included in your portfolio, but should not be resubmitted.")
    TaskStatus.create(name:  "Redo", description:  "This task needs to be redone.")
    TaskStatus.create(name:  "Discuss", description:  "Your work looks good, discuss it with your tutor to complete.")
    TaskStatus.create(name:  "Ready to Mark", description:  "This task is ready for the tutor to assess to provide feedback.")
    TaskStatus.create(name:  "Demonstrate", description:  "Your work looks good, demonstrate it to your tutor to complete.")
    TaskStatus.create(name:  "Fail", description:  "You did not successfully demonstrate the required learning in this task.")

    roles = [
      { name: 'Student', description: "Students are able to be enrolled into units, and to submit progress for their unit projects." },
      { name: 'Tutor', description: "Tutors are able to supervise tutorial classes and provide feedback to students, they may also be students in other units" },
      { name: 'Convenor', description: "Convenors are able to create and manage units, as well as act as tutors and students." },
      { name: 'Admin', description: "Admin are able to create convenors, and act as convenors, tutors, and students in units." }
    ]

    puts "----> Adding Roles"
    role_cache = {}
    roles.each do |role|
        Role.create!(name: role[:name], description: role[:description])
    end

    admins = {
        acain:  {first: "Andrew", last: "Cain", nickname: "Macite"},
        ajones: {first: "Allan",  last: "Jones",   nickname: "P-Jiddy"}
    }

    puts "--> Adding Admins"
    admins.each do |username, info|
      # Create superuser
      User.populate(1) do |superuser|
          superuser.username              = username.to_s
          superuser.nickname              = info[:nickname]
          superuser.email                 = "#{username.to_s}@swin.edu.au"
          superuser.encrypted_password    = BCrypt::Password.create("password")
          superuser.first_name            = info[:first]
          superuser.last_name             = info[:last]
          superuser.sign_in_count         = 0
          superuser.role_id               = Role.admin.id
      end
    end
  end
end
