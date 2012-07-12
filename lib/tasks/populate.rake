namespace :db do
	desc "Clear the database and fill with test data"
	task :populate => :environment do
		require 'populator'
		require 'faker'
		require 'bcrypt'

		# Clear the database
		[Project, ProjectMembership, ProjectStatus, Task, TaskInstance, TaskStatus, Team, User].each(&:delete_all)
	
		# Create 5 projects
		Project.populate(5) do |project|
			project.name = Populator.words(1..3).titleize
			project.description = Populator.words(10..15)
			project.start_date = Date.today
			project.end_date = 12.weeks.from_now

			# Create 6-12 tasks per project
			num_tasks = 6 + rand(12)
			Task.populate(num_tasks) do |task, index|
				task.name = "Assignment #{index}"
				task.project_id = project.id
				task.description = Populator.words(5..10)
				task.weighting = 1/num_tasks
				task.required = rand < 0.1 	# 10% chance of being false
			end
		end

		# Create 5 users
		User.populate(5) do |user|
			user.email = Faker::Internet.email
			user.encrypted_password = BCrypt::Password.create("password")
			user.first_name = Faker::Name.first_name
			user.last_name = Faker::Name.last_name
			user.sign_in_count = 0
		end

		# Populate project/task statuses
		TaskStatus.create(:name => "Not complete", :description => "This task has not been signed off by your tutor.")
		TaskStatus.create(:name => "Needs fixing", :description => "This task must be resubmitted after fixing some issues.")
		TaskStatus.create(:name => "Complete", :description => "This task has been signed off by your tutor.")
	end
end