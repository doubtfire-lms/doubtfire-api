namespace :db do
	desc "Test CSV importing functionality"
	task :testcsv => :environment do
		require 'populator'
		require 'faker'
		require 'bcrypt'

	    # List of subject names to use
	    subjects = [
	      "Object-Oriented Programming",
	    ]

		# Collection of weekdays
	    days = %w[Monday Tuesday Wednesday Thursday Friday]

	    # Clear the database
	    [Unit, Project, TaskDefinition, Task, TaskStatus, Tutorial, UnitRole, User, ProjectConvenor].each(&:delete_all)

	    TaskStatus.create(:name => "Not Submitted", :description => "This task has not been submitted to marked by your tutor.")
	    TaskStatus.create(:name => "Needs Fixing", :description => "This task must be resubmitted after fixing some issues.")
	    TaskStatus.create(:name => "Complete", :description => "This task has been signed off by your tutor.")

		# Create superuser
		User.populate(1) do |superuser|
			superuser.username = "superuser"
			superuser.nickname = "superuser"
			superuser.email = "#{superuser.username}@doubtfire.com"
			superuser.encrypted_password = BCrypt::Password.create("password")
			superuser.first_name = "Super"
			superuser.last_name = "User"
			superuser.sign_in_count = 0
			superuser.system_role = "superuser"
		end

		# Create convenor
		User.populate(1) do |superuser|
			superuser.username = "convenor"
			superuser.nickname = "convenor"
			superuser.email = "#{superuser.username}@doubtfire.com"
			superuser.encrypted_password = BCrypt::Password.create("password")
			superuser.first_name = "Clinton"
			superuser.last_name = "Woodward"
			superuser.sign_in_count = 0
			superuser.system_role = "convenor"
		end

		# Create projects (subjects)
   		subjects.each do |subject|
	      	Unit.populate(1) do |unit|
		        unit.name = subject
		        unit.description  = Populator.words(10..15)
		        unit.start_date   = Date.new(2012, 8, 6)
		        unit.end_date     = 13.weeks.since unit.start_date

		        # Assign a convenor to each project
		        ProjectConvenor.populate(1) do |pa|
		          pa.user_id = 2
		          pa.unit_id = unit.id
		        end

		        # Create 6-12 tasks per project
		        num_tasks = 6 + rand(6)
		        assignment_num = 0
		        TaskDefinition.populate(num_tasks) do |task_definition|
		          assignment_num += 1
		          task_definition.name = "Assignment #{assignment_num}"
		          task_definition.unit_id = unit.id
		          task_definition.description = Populator.words(5..10)
		          task_definition.weighting = BigDecimal.new("2")
		          task_definition.required = rand < 0.9   # 10% chance of being false
		          task_definition.recommended_completion_date = assignment_num.weeks.from_now # Assignment 6 due week 6, etc.
		        end

		        # Create 2 tutorials per project
		        Tutorial.populate(2) do |tutorial|
		          tutorial.unit_id = unit.id
		          tutorial.meeting_day = days.sample
		          tutorial.meeting_time = "#{8 + rand(12)}:#{['00', '30'].sample}"    # Mon-Fri 8am-7:30pm
		          tutorial.meeting_location = "#{['EN', 'BA'].sample}#{rand(7)}#{rand(1)}#{rand(9)}" # EN###/BA###
		          tutorial.user_id = 2
		        end
		    end
      	end

      	#Unit.find(1).import_users_from_csv('./oop.csv')
	end
end