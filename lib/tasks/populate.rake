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
		[Project, ProjectMembership, ProjectStatus, Task, TaskInstance, TaskStatus, Team, TeamMembership, User].each(&:delete_all)
	
		# Create 4 users
		User.populate(4) do |user|
			user.email = Faker::Internet.email
			user.encrypted_password = BCrypt::Password.create("password")
			user.first_name = Faker::Name.first_name
			user.last_name = Faker::Name.last_name
			user.sign_in_count = 0
		end

		User.populate(1) do |user|
			user.email = "student@doubtfire.com"
			user.encrypted_password = BCrypt::Password.create("password")
			user.first_name = "Hercules"
			user.last_name = "Noobston"
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
				project.end_date = 13.weeks.from_now

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
					task.recommended_completion_date = assignment_num.weeks.from_now	# Assignment 6 due week 6, etc.
				end

				# Create 2 teams per project
				team_num = 1
				Team.populate(2) do |team|
					team.project_id = project.id
					team.meeting_time = "#{days.sample} #{8 + rand(12)}:#{['00', '30'].sample}"				# Mon-Fri 8am-7:30pm
					team.meeting_location = "#{['EN', 'BA'].sample}#{rand(7)}#{rand(1)}#{rand(9)}" # EN###/BA###
					
					if team_num == 1
						team.user_id = 5	# Tutor 1
					else
						team.user_id = 6	# Tutor 2
					end
					
					team_num += 1
				end
			end
		end

		# Put each user in each project, in one team or the other
		User.all[0..4].each_with_index do |user, i|
			current_project = 1
			TeamMembership.populate(Project.count) do |team_membership|
				team_membership.team_id = Team.where("project_id = ?", current_project).sample.id
				team_membership.user_id = user.id

				# For each team membership, create a corresponding project membership
				ProjectMembership.populate(1) do |project_membership|
					project_membership.project_status_id = 1
					project_membership.project_id = current_project
					project_membership.project_role = "student"

					# Set the foreign keys for the 1:1 relationship
					project_membership.team_membership_id = team_membership.id
					team_membership.project_membership_id = project_membership.id

					# Create a set of task instances for the current project membership
					tasks_for_project = Task.where("project_id = ?", current_project)
					tasks_for_project.each do |task|
						TaskInstance.populate(1) do |task_instance|
							task_instance.task_id = task.id
							task_instance.project_membership_id = project_membership.id
							task_instance.task_status_id = 1
							task_instance.awaiting_signoff = false
						end
					end

				end

				current_project += 1
			end
		end
	end
end






