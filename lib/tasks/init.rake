namespace :db do
	desc "Initialise the app with an empty database and only minimal users (the superuser)"
	task :init => :environment do
		require 'populator'
		require 'faker'
		require 'bcrypt'

		# Clear the database
		[ProjectTemplate, Project, ProjectStatus, TaskTemplate, Task, TaskStatus, Team, TeamMembership, User, ProjectConvenor].each(&:delete_all)

    TaskStatus.create(:name => "Not Submitted", :description => "This task has not been submitted to marked by your tutor.")
    TaskStatus.create(:name => "Needs Fixing", :description => "This task must be resubmitted after fixing some issues.")
    TaskStatus.create(:name => "Complete", :description => "This task has been signed off by your tutor.")
    TaskStatus.create(:name => "Need Help", :description => "Some help is required in order to complete this task.")
    TaskStatus.create(:name => "Working On It", :description => "This task is currently being worked on.")

		admins = {
     	ajones:         {first: "Allan",   last: "Jones",   nickname: "P-Jiddy"},
    	akihironoguchi: {first: "Akihiro", last: "Noguchi", nickname: "Unneccesary Animations"}
  	}

    convenors = {
    	acain: 	   {first: "Andrew",   last: "Cain",     nickname: "Macite"},
    	cwoodward: {first: "Clinton",  last: "Woodward", nickname: "Tall"},
    }

    admins.each do |username, info|
    	# Create superuser
			User.populate(1) do |superuser|
				superuser.username 			 = username.to_s
				superuser.nickname 			 = info[:nickname]
				superuser.email 			 = "#{username.to_s}@swin.edu.au"
				superuser.encrypted_password = BCrypt::Password.create("d872$dh")
				superuser.first_name 		 = info[:first]
				superuser.last_name 		 = info[:last]
				superuser.sign_in_count 	 = 0
				superuser.system_role 		 = "superuser"
			end
    end

    convenors.each do |username, info|
  		# Create convenor
			User.populate(1) do |convenor|
				convenor.username 			 = username.to_s
				convenor.nickname 			 = info[:nickname]
				convenor.email 				 = "#{username.to_s}@swin.edu.au"
				convenor.encrypted_password  = BCrypt::Password.create("password")
				convenor.first_name 		 = info[:first]
				convenor.last_name 			 = info[:last]
				convenor.sign_in_count 		 = 0
				convenor.system_role 		 = "convenor"
			end
    end

	end
end