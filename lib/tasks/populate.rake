namespace :db do

  desc "Clear the database and fill with test data"
  task :populate => :environment do
    require 'populator'
    require 'faker'
    require 'bcrypt'

    # Collection of tutor/convenor/superuser ids to avoid hard-coding
    ids = {
      "convenor" => -1,
      "superuser" => -1
    }

    tutors = {
      acain:      {first: "Andrew",   last: "Cain", id: -1},
      cwoodward:  {first: "Clinton",  last: "Woodward", id: -1 },
    }

    # List of first and last names to use
    names = {
      "Allan" => "Jones",
      "Rohan" => "Liston",
      "Joost" => "Cornelius Copernicus Pocohontas Archimedes Gandalf Bilbo Samantha Evelyn Goldmember Funke Kupper",
      "Akihiro" => "Noguchi"
    }

    # List of subject names to use
    subjects = [
      "Introduction To Programming",
      "Object-Oriented Programming",
      "Games Programming",
      "AI For Games"
    ]

    # Collection of weekdays
    days = %w[Monday Tuesday Wednesday Thursday Friday]

    # Clear the database
    [ProjectTemplate, Project, ProjectStatus, TaskTemplate, Task, TaskStatus, Team, TeamMembership, User, ProjectAdministrator].each(&:delete_all)
  
    # Populate project/task statuses
    ProjectStatus.create(:health => 100)
    
    TaskStatus.create(:name => "Not Submitted", :description => "This task has not been submitted to marked by your tutor.")
    TaskStatus.create(:name => "Needs Fixing", :description => "This task must be resubmitted after fixing some issues.")
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
    tutors.each do |username, info|
      User.populate(1) do |tutor|
        tutor.email = "#{username.to_s}@doubtfire.com"
        tutor.encrypted_password  = BCrypt::Password.create("password")
        tutor.first_name          = info[:first]
        tutor.last_name           = info[:last]
        tutor.sign_in_count       = 0
        tutor.system_role         = "user"
        tutors[username][:id]     = tutor.id
      end
    end

    # Create 1 convenor
    User.populate(1) do |admin|
      admin.email = "convenor@doubtfire.com"
      admin.encrypted_password = BCrypt::Password.create("password")
      admin.first_name = "Clinton"
      admin.last_name = "Woodward"
      admin.sign_in_count = 0
      admin.system_role = "convenor"
      ids["convenor"] = admin.id
    end

    # Create 1 superuser
    User.populate(1) do |su|
      su.email = "superuser@doubtfire.com"
      su.encrypted_password = BCrypt::Password.create("password")
      su.first_name = "Super"
      su.last_name = "User"
      su.sign_in_count = 0
      su.system_role = "superuser"
      ids["superuser"] = su.id
    end

    # Create 4 projects (subjects)
    subjects.each do |subject|
      ProjectTemplate.populate(1) do |project_template|
        project_template.name = subject
        project_template.description  = Populator.words(10..15)
        project_template.start_date   = Date.new(2012, 8, 6)
        project_template.end_date     = 13.weeks.since project_template.start_date

        # Assign a convenor to each project
        ProjectAdministrator.populate(1) do |pa|
          pa.user_id = ids["convenor"]   # Convenor 1
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
        team_num = 1
        Team.populate(2) do |team|
          team.project_template_id = project_template.id
          team.meeting_time = "#{days.sample} #{8 + rand(12)}:#{['00', '30'].sample}"    # Mon-Fri 8am-7:30pm
          team.meeting_location = "#{['EN', 'BA'].sample}#{rand(7)}#{rand(1)}#{rand(9)}" # EN###/BA###
          
          if ["Introduction To Programming", "Object-Oriented Programming"].include? subject
            team.user_id = tutors[:acain][:id]  # Tutor 1
          else
            team.user_id = tutors[:cwoodward][:id]  # Tutor 2
          end
          
          team_num += 1
        end
      end
    end

    # Put each user in each project, in one team or the other
    User.all[0..3].each do |user|
      ProjectTemplate.all.each do |project_template|
        random_project_team = Team.where(:project_template_id => project_template.id).sample
        project_template.add_user(user.id, random_project_team.id, "student")
      end
    end
 
    complete_status = TaskStatus.where(:name=> "Complete").first

    User.where(:first_name => "Allan").each do |allan|
      allan.team_memberships.each do |team_membership|
        project = team_membership.project

        project.tasks.each do |task|
          task.awaiting_signoff = true
          task.save
        end
      end
    end

    User.where(:first_name => "Rohan").each do |rohan|
      rohan.team_memberships.each do |team_membership|
        project = team_membership.project

        project.tasks.each do |task|
          task.task_status = complete_status
          task.save
        end
      end
    end
  end
end
