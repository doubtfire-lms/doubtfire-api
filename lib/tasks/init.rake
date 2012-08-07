namespace :db do
	desc "Initialise the app with an empty database and only minimal users (the superuser)"
	task :init => :environment do
		require 'populator'
		require 'faker'
		require 'bcrypt'

		# Clear the database
		[ProjectTemplate, Project, ProjectStatus, TaskTemplate, Task, TaskStatus, Team, TeamMembership, User, ProjectConvenor].each(&:delete_all)

		# Create superuser
		User.populate(1) do |superuser|
			superuser.username = "superuser"
			superuser.nickname = "superuser"
			superuser.email = "#{superuser.username}@doubtfire.com"
			superuser.encrypted_password = BCrypt::Password.create("d872$dh")
			superuser.first_name = "Super"
			superuser.last_name = "User"
			superuser.sign_in_count = 0
			superuser.system_role = "superuser"
		end
	end
end