namespace :db do

  desc "Clear the database and fill with test data"
  task populate: [:setup, :migrate] do
    require 'populator'
    require 'faker'
    require 'bcrypt'

    roles = [
      :student,
      :tutor,
      :convenor,
      :moderator
    ]

    tutors = {
      acain:      {first: "Andrew",   last: "Cain", id: -1},
      cwoodward:  {first: "Clinton",  last: "Woodward", id: -1 },
    }

    # FIXME: Not enough hilarious names
    joosts_long_ass_name = %w[
      Cornelius
      Pocohontas
      Funke
      Kupper
    ].join(" ")

    randies = {
      ajones:             {first: "Allan",    last: "Jones",                nickname: "P-Jiddy"},
      rliston:            {first: "Rohan",    last: "Liston",               nickname: "Gunner"},
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

    TaskStatus.create(name:  "Not Submitted", description:  "This task has not been submitted to marked by your tutor.")
    TaskStatus.create(name:  "Complete", description:  "This task has been signed off by your tutor.")
    TaskStatus.create(name:  "Need Help", description:  "Some help is required in order to complete this task.")
    TaskStatus.create(name:  "Working On It", description:  "This task is currently being worked on.")
    TaskStatus.create(name:  "Fix and Resubmit", description:  "This task must be resubmitted after fixing some issues.")
    TaskStatus.create(name:  "Fix and Include", description:  "This task must be fixed and included in your portfolio, but should not be resubmitted.")
    TaskStatus.create(name:  "Redo", description:  "This task needs to be redone.")

    role_cache = {}

    roles.each do |role|
      role_cache[role] = Role.create(name: role.to_s.titleize)
    end

    # Create 4 students
    randies.each do |username, profile|
      user = User.create(
        username: username.to_s,
        nickname: profile[:nickname],
        email: "#{username}@doubtfire.com",
        password: 'password',
        password_confirmation: 'password',
        first_name: profile[:first],
        last_name: profile[:last],
        system_role: "basic"
      )

      UserRole.create(user_id: user.id, role_id: role_cache[:student])
    end

    tutor_cache = {}

    # Create 2 tutors
    tutors.each do |username, info|
      tutor_cache[username] = User.create(
        username: username.to_s,
        nickname: info[:nickname],
        email: "#{username.to_s}@doubtfire.com",
        password: 'password',
        password_confirmation: 'password',
        first_name: info[:first],
        last_name: info[:last],
        system_role: "basic"
      )
    end

    # Create 1 convenor
    convenor = User.create(
      username: "convenor",
      nickname: "Strict",
      email: "convenor@doubtfire.com",
      password: 'password',
      password_confirmation: 'password',
      first_name: "Convenor",
      last_name: "OfSubjects",
      system_role: "admin"
    )

     # Create 1 superuser
    User.create(
      username: "superuser",
      nickname: "Strict",
      email: "superuser@doubtfire.com",
      password: 'password',
      password_confirmation: 'password',
      first_name: "Somedude",
      last_name: "Withlotsapower",
      system_role: "admin"
    )

    unit_role_cache = {}

    # Create 4 projects (subjects)
    subjects.each do |subject_code, subject_name|
      unit = Unit.create(
        code: subject_code,
        name: subject_name,
        description: Populator.words(10..15),
        start_date: Date.current,
        end_date: 13.weeks.since(Date.current)
      )

      unit_role_cache[subject_code] ||= {}
      unit_role_cache[subject_code][:convenor] = UnitRole.create(role_id: role_cache[:convenor], user_id: convenor.id)

      # Create 6-12 tasks per project
      task_count = 6 + rand(6)

      task_count.times do |count|
        TaskDefinition.create(
          name: "Assignment #{count + 1}",
          abbreviation: "A#{count + 1}",
          unit_id: unit.id,
          description: Populator.words(5..10),
          weighting: BigDecimal.new("2"),
          required: rand < 0.9,   # 10% chance of being false
          target_date: (count + 1).weeks.from_now # Assignment 6 due week 6, etc.
        )
      end

      # Create 2 tutorials per project
      tutorial_num = 1

      tutor_unit_role = if ["Introduction To Programming", "Object-Oriented Programming"].include? subject_name
        unit_role_cache[subject_code][:acain] ||= UnitRole.create!(role_id: role_cache[:tutor].id, user_id: tutor_cache[:acain].id, unit_id: unit.id)
      else
        unit_role_cache[subject_code][:cwoodward] ||= UnitRole.create!(role_id: role_cache[:tutor].id, user_id: tutor_cache[:cwoodward].id, unit_id: unit.id)
      end

      2.times do |count|
        Tutorial.create(
          unit_id: unit.id,
          unit_role_id: tutor_unit_role.id,
          meeting_time: "#{8 + rand(12)}:#{['00', '30'].sample}",    # Mon-Fri 8am-7:30pm
          meeting_day: "#{days.sample}",
          meeting_location: "#{['EN', 'BA'].sample}#{rand(7)}#{rand(1)}#{rand(9)}" # EN###/BA###
        )
      end
    end

    # Put each user in each project, in one tutorial or the other
    User.all[0..3].each do |user|
      Unit.all.each do |unit|
        random_project_tutorial = Tutorial.where(unit_id:  unit.id).sample
        unit.add_user(user.id, random_project_tutorial.id, "student")
      end
    end

    complete_status = TaskStatus.where(:name=> "Complete").first

    User.where(username:  "ajones").each do |allan|
      allan.unit_roles.each do |unit_role|
        project = unit_role.project

        project.tasks.each do |task|
          task.awaiting_signoff = false
          task.save
        end

        project.calculate_temporal_attributes
        project.save
      end
    end

    User.where(username:  "rliston").each do |rohan|
      rohan.unit_roles.each do |unit_role|
        project = unit_role.project

        project.tasks.each do |task|
          task.task_status = complete_status
          task.completion_date = Time.zone.now
          task.save
        end

        project.calculate_temporal_attributes
        project.save
      end
    end
  end
end
