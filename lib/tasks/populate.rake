namespace :db do
	desc "Clear the database and fill with test data"
	task :populate => :environment do
		require 'populator'
		require 'faker'
		require 'bcrypt'

		# List of first and last names to use
		names = {"Allan" => "Jones",
				 "Rohan" => "Liston",
				 "Joost" => "Cornelius Pocohontas Archimedes Funke Kupper",
				 "Akihiro" => "Noguchi"}

		# List of subject names to use
		subjects = ["Introduction To Programming",
					"Object-Oriented Programming",
					"Games Programming",
					"AI For Games"]

		# Collection of weekdays
		days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

		# Clear the database
		[ProjectTemplate, Project, ProjectStatus, TaskTemplate, Task, 
						  TaskStatus, Team, TeamMembership, User, ProjectAdministrator].each(&:delete_all)
	
		# Populate project/task statuses
		ProjectStatus.create(:health => 100)
		TaskStatus.create(:name => "Not complete", :description => "This task has not been signed off by your tutor.")
		TaskStatus.create(:name => "Needs fixing", :description => "This task must be resubmitted after fixing some issues.")
		TaskStatus.create(:name => "Complete", :description => "This task has been signed off by your tutor.")

		# Create 4 students
		names.each do |first, last|
			User.populate(1) do |user|
				user.email = "#{first.downcase}@doubtfire.com"
				user.encrypted_password = BCrypt::Password.create("password")
				user.first_name = first
				user.last_name = last
				user.sign_in_count = 0
				user.system_role = "user"
			end
		end

		# Create 2 tutors
		tutor_num = 1
		User.populate(2) do |tutor|
			tutor.email = "tutor#{tutor_num}@doubtfire.com"
			tutor.encrypted_password = BCrypt::Password.create("password")
			tutor.first_name = "Tutor"
			tutor.last_name =  "#{tutor_num}"
			tutor.sign_in_count = 0
			tutor.system_role = "user"
			tutor_num += 1
		end

		# Create 1 admin
		User.populate(1) do |admin|
			admin.email = "convenor@doubtfire.com"
			admin.encrypted_password = BCrypt::Password.create("password")
			admin.first_name = "Convenor"
			admin.last_name = "1"
			admin.sign_in_count = 0
			admin.system_role = "admin"
		end

		# Create 1 superuser
		User.populate(1) do |su|
			su.email = "superuser@doubtfire.com"
			su.encrypted_password = BCrypt::Password.create("password")
			su.first_name = "Super"
			su.last_name = "User"
			su.sign_in_count = 0
			su.system_role = "superuser"
		end

		# Create 4 projects (subjects)
		subjects.each do |subject|
			ProjectTemplate.populate(1) do |project_template|
				project_template.name = subject
				project_template.description = Populator.words(10..15)
				project_template.start_date = Date.today
				project_template.end_date = 13.weeks.from_now

				# Create 6-12 tasks per project
				num_tasks = 6 + rand(6)
				assignment_num = 0
				TaskTemplate.populate(num_tasks) do |task_template|
					assignment_num += 1
					task_template.name = "Assignment #{assignment_num}"
					task_template.project_template_id = project_template.id
					task_template.description = Populator.words(5..10)
					task_template.weighting = 1/num_tasks
					task_template.required = rand < 0.9 	# 10% chance of being false
					task_template.recommended_completion_date = assignment_num.weeks.from_now	# Assignment 6 due week 6, etc.
				end

				# Create 2 teams per project
				team_num = 1
				Team.populate(2) do |team|
					team.project_template_id = project_template.id
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
		User.all[0..3].each_with_index do |user, i|
			current_project_template_id = 1
			TeamMembership.populate(ProjectTemplate.count) do |team_membership|
				team_membership.team_id = Team.where("project_template_id = ?", current_project_template_id).sample.id
				team_membership.user_id = user.id

				# For each team membership, create a corresponding project membership
				Project.populate(1) do |project|
					project.project_status_id = 1
					project.project_template_id = current_project_template_id
					project.project_role = "student"

					# Set the foreign keys for the 1:1 relationship
					project.team_membership_id = team_membership.id
					team_membership.project_id = project.id

					# Create a set of task instances for the current project membership
					template_tasks_for_project = TaskTemplate.where("project_template_id = ?", current_project_template_id)
					template_tasks_for_project.each do |task_template|
						Task.populate(1) do |task|
							task.task_template_id = task_template.id
							task.project_id = project.id
							task.task_status_id = 1
							task.awaiting_signoff = false
						end
					end

				end

				current_project_template_id += 1
			end
		end
	end
end






