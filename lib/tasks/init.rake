namespace :db do
	desc "Initialise the app with an empty database and only minimal users (the superuser and two convenors)"
	task :init => :environment do
		require 'populator'
		require 'faker'
		require 'bcrypt'

		# Clear the database
		[ProjectTemplate, Project, ProjectStatus, TaskTemplate, Task, 
						  TaskStatus, Team, TeamMembership, User, ProjectAdministrator].each(&:delete_all)

		# Create superuser
		User.populate(1) do |superuser|
			superuser.email = "superuser@doubtfire.com"
			superuser.encrypted_password = BCrypt::Password.create("password")
			superuser.first_name = "Super"
			superuser.last_name = "User"
			superuser.sign_in_count = 0
			superuser.system_role = "superuser"
		end

		# Create convenor 1
		User.populate(1) do |superuser|
			superuser.email = "convenor@doubtfire.com"
			superuser.encrypted_password = BCrypt::Password.create("password")
			superuser.first_name = "Clinton"
			superuser.last_name = "Woodward"
			superuser.sign_in_count = 0
			superuser.system_role = "convenor"
		end

		# Create convenor 2
		User.populate(1) do |superuser|
			superuser.email = "convenor2@doubtfire.com"
			superuser.encrypted_password = BCrypt::Password.create("password")
			superuser.first_name = "Andrew"
			superuser.last_name = "Cain"
			superuser.sign_in_count = 0
			superuser.system_role = "convenor"
		end
	end
end