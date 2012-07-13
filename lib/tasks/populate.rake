namespace :db do
	desc "Clear the database and fill with test data"
	task :populate => :environment do
		require 'populator'
		require 'faker'
		require 'bcrypt'

		subjects = ["Introduction To Programming",
					"Object-Oriented Programming",
					"Games Programming",
					"AI For Games"]

		days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

		# Clear the database
		[Project, ProjectMembership, ProjectStatus, Task, TaskInstance, TaskStatus, Team, User].each(&:delete_all)
	
		# Create 4 users
		User.populate(4) do |user|
			user.email = Faker::Internet.email
			user.encrypted_password = BCrypt::Password.create("password")
			user.first_name = Faker::Name.first_name
			user.last_name = Faker::Name.last_name
			user.sign_in_count = 0
		end

		# Create 2 tutors
		tutor_num = 1
		User.populate(2) do |tutor|
			tutor.email = "tutor#{tutor_num}@doubtfire.com"
			tutor.encrypted_password = BCrypt::Password.create("password")
			tutor.first_name = "Tutor"
			tutor.last_name =  "#{tutor_num}"
			tutor.sign_in_count = 0
			tutor_num += 1
		end

		# Populate project/task statuses
		ProjectStatus.create(:health => 100)
		TaskStatus.create(:name => "Not complete", :description => "This task has not been signed off by your tutor.")
		TaskStatus.create(:name => "Needs fixing", :description => "This task must be resubmitted after fixing some issues.")
		TaskStatus.create(:name => "Complete", :description => "This task has been signed off by your tutor.")

		# Create 4 projects (subjects)
		subjects.each do |subject|
			Project.populate(1) do |project|
				project.name = subject
				project.description = Populator.words(10..15)
				project.start_date = Date.today
				project.end_date = 12.weeks.from_now

				# Create 6-12 tasks per project
				num_tasks = 6 + rand(6)
				assignment_num = 0
				Task.populate(num_tasks) do |task|
					assignment_num += 1
					task.name = "Assignment #{assignment_num}"
					task.project_id = project.id
					task.description = Populator.words(5..10)
					task.weighting = 1/num_tasks
					task.required = rand < 0.9 	# 10% chance of being false
				end

				# Create 2 teams per project
				team_num = 1
				Team.populate(2) do |team|
					team.project_id = project.id
					team.meeting_time = "#{days.sample} #{rand(8..19)}:#{['00', '30'].sample}"	# Mon-Fri 8am-7:30pm
					team.meeting_location = "#{['EN', 'BA'].sample}#{rand(1..7)}#{rand(0..1)}#{rand(1..9)}" 
					
					if team_num == 1
						team.user_id = 5	# Tutor 1
					else
						team.user_id = 6	# Tutor 2
					end
					
					team_num += 1
				end

				# Put each user in a team
				#User.all.each do |user|
				#	TeamMembership.populate(1) do |team_membership|
				#		team_membership.user_id = user.id
				#       team_membership.team_id = Team.where("project_id = ?", project.id).sample.id 	# Random team for the current project
				#	end
				#end
			end
		end
	end
end






