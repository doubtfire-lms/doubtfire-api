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

    # FIXME: Not enough hilarious names
    joosts_long_ass_name = %w[
      Cornelius
      Copernicus
      Indiana
      Pocohontas
      Albus
      Severus
      Archimedes
      Gandalf
      Bilbo
      Samantha
      Evelyn
      Goldmember
      Ernie
      Bert
      Grover
      Funke
      Kupper
    ].join(" ")

    randies = {
      ajones:              {first: "Allan",    last: "Jones",                nickname: "P-Jiddy"},
      rliston:              {first: "Rohan",    last: "Liston",               nickname: "Gunner"},
      akihironoguchi:     {first: "Akihiro",  last: "Noguchi",              nickname: "Unneccesary Animations"},
      joostfunkekupper:   {first: "Joost",    last: joosts_long_ass_name,   nickname: "Joe"}
    }

    # List of subject names to use
    subjects = {
      "HIT2080" => "Introduction To Programming",
      "HIT2302" => "Object-Oriented Programming",
      "HIT3243" => "Games Programming",
      "HIT3046" => "Artificial Intelligence for Games"
    }

    # Collection of weekdays
    days = %w[Monday Tuesday Wednesday Thursday Friday]

    # Clear the database
    [ProjectTemplate, Project, ProjectStatus, TaskTemplate, Task, TaskStatus, Team, TeamMembership, User, ProjectConvenor].each(&:delete_all)
  
    # Populate project/task statuses
    ProjectStatus.create(:health => 100)
    
    TaskStatus.create(:name => "Not Submitted", :description => "This task has not been submitted to marked by your tutor.")
    TaskStatus.create(:name => "Needs Fixing", :description => "This task must be resubmitted after fixing some issues.")
    TaskStatus.create(:name => "Complete", :description => "This task has been signed off by your tutor.")

    # Create 4 students
    randies.each do |username, profile|
      User.populate(1) do |user|
        user.username           = username.to_s
        user.nickname           = profile[:nickname]
        user.email              = "#{username}@doubtfire.com"
        user.encrypted_password = BCrypt::Password.create("password")
        user.first_name         = profile[:first]
        user.last_name          = profile[:last]
        user.sign_in_count      = 0
        user.system_role        = "user"
      end
    end

    # Create 2 tutors
    tutors.each do |username, info|
      User.populate(1) do |tutor|
        tutor.username             = username.to_s
        tutor.nickname             = info[:nickname]
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
    User.populate(1) do |convenor|
      convenor.username            = "convenor"
      convenor.nickname            = "Strict"
      convenor.email               = "convenor@doubtfire.com"
      convenor.encrypted_password  = BCrypt::Password.create("password")
      convenor.first_name          = "Somedude"
      convenor.last_name           = "Withlotsapower"
      convenor.sign_in_count       = 0
      convenor.system_role         = "convenor"
      ids["convenor"]           = convenor.id
    end

    # Create 1 superuser
    User.populate(1) do |su|
      su.username = "superuser"
      su.nickname = "God"
      su.email = "superuser@doubtfire.com"
      su.encrypted_password = BCrypt::Password.create("password")
      su.first_name = "Super"
      su.last_name = "User"
      su.sign_in_count = 0
      su.system_role = "superuser"
      ids["superuser"] = su.id
    end

    # Create 4 projects (subjects)
    subjects.each do |subject_code, subject_name|
      ProjectTemplate.populate(1) do |project_template|
        project_template.official_name  = subject_code
        project_template.name           = subject_name
        project_template.description    = Populator.words(10..15)
        project_template.start_date     = Date.new(2012, 8, 6)
        project_template.end_date       = 13.weeks.since project_template.start_date

        # Assign a convenor to each project
        ProjectConvenor.populate(1) do |pa|
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
          team.meeting_time = "#{8 + rand(12)}:#{['00', '30'].sample}"    # Mon-Fri 8am-7:30pm
          team.meeting_day  = "#{days.sample}"
          team.meeting_location = "#{['EN', 'BA'].sample}#{rand(7)}#{rand(1)}#{rand(9)}" # EN###/BA###
          
          if ["Introduction To Programming", "Object-Oriented Programming"].include? subject_name
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

    User.where(:username => "ajones").each do |allan|
      allan.team_memberships.each do |team_membership|
        project = team_membership.project

        project.tasks.each do |task|
          task.awaiting_signoff = true
          task.save
        end
      end
    end

    User.where(:username => "rliston").each do |rohan|
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
