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
	    [ProjectTemplate, Project, ProjectStatus, TaskTemplate, Task, TaskStatus, Team, TeamMembership, User, ProjectConvenor].each(&:delete_all)

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
	      	ProjectTemplate.populate(1) do |project_template|
		        project_template.name = subject
		        project_template.description  = Populator.words(10..15)
		        project_template.start_date   = Date.new(2012, 8, 6)
		        project_template.end_date     = 13.weeks.since project_template.start_date

		        # Assign a convenor to each project
		        ProjectConvenor.populate(1) do |pa|
		          pa.user_id = 2
		          pa.project_template_id = project_template.id
		        end

		        # Create 6-12 tasks per project
		        num_tasks = 6 + rand(6)
		        assignment_num = 0
		        TaskTemplate.populate(num_tasks) do |task_template|
		          assignment_num += 1
		          task_template.name = "Assignment #{assignment_num}"
		          task_template.project_template_id = project_template.id
		          task_template.description = Populator.words(5..10)
		          task_template.weighting = BigDecimal.new("2")
		          task_template.required = rand < 0.9   # 10% chance of being false
		          task_template.recommended_completion_date = assignment_num.weeks.from_now # Assignment 6 due week 6, etc.
		        end

		        # Create 2 teams per project
		        Team.populate(2) do |team|
		          team.project_template_id = project_template.id
		          team.meeting_day = days.sample
		          team.meeting_time = "#{8 + rand(12)}:#{['00', '30'].sample}"    # Mon-Fri 8am-7:30pm
		          team.meeting_location = "#{['EN', 'BA'].sample}#{rand(7)}#{rand(1)}#{rand(9)}" # EN###/BA###
		          team.user_id = 2
		        end
		    end
      	end

      	#ProjectTemplate.find(1).import_users_from_csv('./oop.csv')
	end
end