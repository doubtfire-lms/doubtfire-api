namespace :db do
	desc "Initialise the app with an empty database and a single user (the superuser)"
	task :init => :environment do
		require 'populator'
		require 'faker'
		require 'bcrypt'

		# Clear database
		[Project, ProjectMembership, ProjectStatus, Task, TaskInstance, TaskStatus, 
				  Team, TeamMembership, User, ProjectAdministrator, SystemRole].each(&:delete_all)

		# Create superuser
		User.populate(1) do |superuser|
			superuser.email = "superuser@doubtfire.com"
			superuser.encrypted_password = BCrypt::Password.create("password")
			superuser.first_name = "Super"
			superuser.last_name = "User"
			superuser.sign_in_count = 0
			superuser.system_role_id = 3
		end
	end
end