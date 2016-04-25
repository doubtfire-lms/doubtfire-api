namespace :db do

  desc "Mark off some of the due tasks"
  task expand_first_unit: :environment do

    find_or_create_student = lambda { |username|
      result = User.find_by_username(username)
      if result
        return result
      else
        profile = {
          first_name:   Faker::Name.first_name,
          last_name:    Faker::Name.last_name,
          nickname:     username,
          role_id:  Role.student_id,
          email:        "#{username}@doubtfire.com",
          username:     username,
          password:     'password',
          password_confirmation: 'password'
        }

        result = User.create!(profile)
        return result
      end
    }

    unit = Unit.first
    tutes = unit.tutorials
    for student_count in 0..2000
      proj = unit.enrol_student(find_or_create_student.call("student_#{student_count}"), tutes[student_count % tutes.count])
    end
  end

  desc "Mark off some of the due tasks"
  task simulate_signoff: :environment do
    Unit.all.each do |unit|
      current_week = ((Time.zone.now - unit.start_date) / 1.weeks).floor

      unit.students.each do |proj|
        #
        # Get the student project
        #
        p = Project.find(proj.id)
        p.tasks.destroy_all

        # Determine who is assessing their work...
        tutor = p.main_tutor

        p.target_grade = rand(0..3)

        case rand(1..100)
        when 0..5
          kept_up_to_week = current_week + rand(1..4)
          p.target_grade = rand(2..3)
        when 6..10
          kept_up_to_week = current_week + 1
          p.target_grade = rand(1..3)
        when 11..40
          kept_up_to_week = current_week
        when 41..60
          kept_up_to_week = current_week - 1
          kept_up_to_week = 1 unless kept_up_to_week > 0
        when 61..70
          kept_up_to_week = current_week - rand(1..4)
          kept_up_to_week = 1 unless kept_up_to_week > 0
        when 71..80
          kept_up_to_week = current_week - rand(3..10)
          kept_up_to_week = 1 unless kept_up_to_week > 0
        when 81..90
          kept_up_to_week = current_week - rand(3..10)
          kept_up_to_week = 0 unless kept_up_to_week > 0
        else
          kept_up_to_week = 0
          p.target_grade = 0
        end

        p.save

        kept_up_to_date = unit.date_for_week_and_day(kept_up_to_week, 'Fri')

        assigned_task_defs = p.assigned_task_defs.where("target_date <= :up_to_date", up_to_date: kept_up_to_date)

        time_to_complete_task = (kept_up_to_date - (unit.start_date + 1.weeks)) / assigned_task_defs.count

        i = 0
        assigned_task_defs.order("target_date").each do |at|
          task = p.task_for_task_definition(at)
          # if its more than three week past kept up to date...
          if kept_up_to_date >= task.target_date + 2.weeks
            complete_date = unit.start_date + i * time_to_complete_task + rand(7..14).days
            if complete_date < unit.start_date + 1.weeks
              complete_date = unit.start_date + 1.weeks
            elsif complete_date > Time.zone.now
              complete_date = Time.zone.now
            end
            task.assess TaskStatus.complete, tutor, complete_date
          elsif kept_up_to_date >= task.target_date + 1.week
            complete_date = unit.start_date + i * time_to_complete_task + rand(7..14).days
            if complete_date < unit.start_date + 1.weeks
              complete_date = unit.start_date + 1.weeks
            elsif complete_date > Time.zone.now
              complete_date = Time.zone.now
            end

            # 1 to 3
            case rand(1..100)
            when 0..50
              task.assess TaskStatus.complete, tutor, complete_date
            when 51..75
              task.assess TaskStatus.discuss, tutor, complete_date
            when 76..90
              task.assess TaskStatus.demonstrate, tutor, complete_date
            when 91..95
              task.assess TaskStatus.fix_and_resubmit, tutor, complete_date
            when 96..97
              task.assess TaskStatus.working_on_it, tutor, complete_date
            when 97
              task.assess TaskStatus.fix_and_include, tutor, complete_date
            when 98..99
              task.assess TaskStatus.redo, tutor, complete_date
            else
              task.submit complete_date
            end
          else
            complete_date = unit.start_date + i * time_to_complete_task + rand(7..10).days
            if complete_date < unit.start_date + 1.weeks
              complete_date = unit.start_date + 1.weeks
            elsif complete_date > Time.zone.now
              complete_date = Time.zone.now
            end

            # 1 to 3
            case rand(1..100)
            when 0..3
              task.assess TaskStatus.complete, tutor, complete_date
            when 4..60
              task.submit complete_date
            when 61..70
              task.assess TaskStatus.discuss, tutor, complete_date
            when 71..80
              task.assess TaskStatus.demonstrate, tutor, complete_date
            when 81..90
              task.assess TaskStatus.fix_and_resubmit, tutor, complete_date
            when 91..98
              task.assess TaskStatus.working_on_it, tutor, complete_date
            when 99
              task.assess TaskStatus.redo, tutor, complete_date
            else
              task.submit complete_date
            end
          end

          i += 1
        end

        next_assigned_tasks = p.assigned_tasks.where("target_date > :up_to_date AND target_date <= :next_week", up_to_date: kept_up_to_date, next_week: kept_up_to_date + 1.weeks)

        next_assigned_tasks.each do |at|
          task = p.task_for_task_definition(at)
          # 1 to 3
          case rand(1..100)
          when 0..60
            task.assess TaskStatus.working_on_it, tutor, Time.zone.now
          when 60..75
            task.assess TaskStatus.need_help, tutor, Time.zone.now
          end
        end

        p.calc_task_stats
        # puts p.assigned_tasks.map { |e| "#{e.task_definition.abbreviation} #{e.completion_date}"  }
        p.save
      end
    end
  end

  desc "Clear the database and fill with test data"
  task populate: [:setup, :migrate] do
    require 'populator'
    require 'faker'
    require 'bcrypt'
    require 'json'

    scale = ENV["SCALE"] || 'small'

    # if it is small scale less students and tutorials
    if scale == 'small'
      min_students = 5
      delta_students = 2
      few_tasks = 5
      some_tasks = 10
      many_task = 20
      few_tutorials = 1
      some_tutorials = 1
      many_tutorials = 1
      max_tutorials = 4
    else
      min_students = 15
      delta_students = 7
      few_tasks = 10
      some_tasks = 30
      many_task = 50
      few_tutorials = 1
      some_tutorials = 2
      many_tutorials = 4
      max_tutorials = 20
    end

    puts "--> Starting populate (#{scale} scale)"

    roles = [
      :student,
      :tutor,
      :convenor,
      :admin
    ]

    # puts "----> ILO's"

    puts "----> Adding Roles"
    role_cache = {}
    roles.each do |role|
      role_cache[role] = Role.create!(name: role.to_s.titleize)
    end

    users = {
      acain:              {first_name: "Andrew",         last_name: "Cain",                 nickname: "Macite",     role_id: Role.admin_id},
      cwoodward:          {first_name: "Clinton",        last_name: "Woodward",             nickname: "The Giant",  role_id: Role.admin_id},
      ajones:             {first_name: "Allan",          last_name: "Jones",                nickname: "P-Jiddy",    role_id: Role.convenor_id},
      rwilson:            {first_name: "Reuben",         last_name: "Wilson",               nickname: "Reubs",      role_id: Role.convenor_id},
      akihironoguchi:     {first_name: "Akihiro",        last_name: "Noguchi",              nickname: "Animations", role_id: Role.tutor_id},
      cliff:              {first_name: "Cliff",          last_name: "Warren",               nickname: "AvDongle",   role_id: Role.tutor_id},
      joostfunkekupper:   {first_name: "Joost",          last_name: "Funke Kupper",         nickname: "Joe",        role_id: Role.tutor_id},
      angusmorton:        {first_name: "Angus",          last_name: "Morton",               nickname: "Angus",      role_id: Role.tutor_id},
      alexcu:             {first_name: "Alex",           last_name: "Cummaudo",             nickname: "Angus",      role_id: Role.convenor_id},
      paul:               {first_name: "Paul",           last_name: "Jones",                nickname: "Jonsey",     role_id: Role.convenor_id},
      "123456X" =>        {first_name: "Fred",           last_name: "Jones",                nickname: "Foo",        role_id: Role.student_id}
    }

    10.times do |count|
      tutor_name = "tutor_#{count}";
      users[tutor_name] = { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, nickname: tutor_name, role_id: Role.tutor_id}
    end

    unit_data = {
      intro_prog: {
        code: "COS10001",
        name: "Introduction to Programming",
        convenors: [ :acain, :cwoodward ],
        tutors: [
          { user: :acain, num: many_tutorials},
          { user: :cwoodward, num: many_tutorials},
          { user: :ajones, num: many_tutorials},
          { user: :rwilson, num: many_tutorials},
          { user: :akihironoguchi, num: many_tutorials},
          { user: :joostfunkekupper, num: many_tutorials},
          { user: :angusmorton, num: some_tutorials},
          { user: :alexcu, num: some_tutorials},
          { user: "tutor_3", num: some_tutorials},
          { user: "tutor_4", num: some_tutorials},
          { user: :cliff, num: some_tutorials},
          { user: :paul, num: some_tutorials}
          # { user: "tutor_6", num: 4},
          # { user: "tutor_7", num: 4},
          # { user: "tutor_8", num: 4},
          # { user: "tutor_9", num: 4},
          # { user: "tutor_10", num: 4},
        ],
        num_tasks: some_tasks,
        ilos: [
          { ilo_number: 1, abbreviation: 'ILO-1', name: "Create Programs", description: "1. Use compiler\n1. Create code" },
          { ilo_number: 2, abbreviation: 'ILO-2', name: "Test Programs", description: "1. Run program\n1. Check results\n1. Fix code" }
        ],
        students: [ ]
      },
      oop: {
        code: "COS20007",
        name: "Object Oriented Programming",
        convenors: [ :acain, :cwoodward, :ajones ],
        tutors: [
          { user: "tutor_1", num: few_tutorials },
          { user: :alexcu, num: few_tutorials },
          { user: :angusmorton, num: few_tutorials },
          { user: :akihironoguchi, num: few_tutorials },
          { user: :joostfunkekupper, num: few_tutorials },
        ],
        num_tasks: many_task,
        ilos: [
          { ilo_number: 1, abbreviation: 'ILO-1', name: "Create Programs", description: "1. Use compiler\n1. Create code" },
          { ilo_number: 2, abbreviation: 'ILO-2', name: "Test Programs", description: "1. Run program\n1. Check results\n1. Fix code" }
        ],
        students: [ :cliff ]
      },
      ai4g: {
        code: "COS03046",
        name: "Artificial Intelligence for Games",
        convenors: [ :cwoodward ],
        tutors: [
          { user: :cwoodward, num: few_tutorials },
          { user: :cliff, num: few_tutorials },
        ],
        num_tasks: few_tasks,
        ilos: [
          { ilo_number: 1, abbreviation: 'ILO-1', name: "Create Programs", description: "1. Use compiler\n1. Create code" },
          { ilo_number: 2, abbreviation: 'ILO-2', name: "Test Programs", description: "1. Run program\n1. Check results\n1. Fix code" }
        ],
        students: [ :acain, :ajones, :alexcu ]
      },
      gameprog: {
        code: "COS03243",
        name: "Game Programming",
        convenors: [ :cwoodward, :alexcu ],
        tutors: [
          { user: :cwoodward, num: few_tutorials },
        ],
        num_tasks: few_tasks,
        ilos: [
          { ilo_number: 1, abbreviation: 'ILO-1', name: "Create Programs", description: "1. Use compiler\n1. Create code" },
          { ilo_number: 2, abbreviation: 'ILO-2', name: "Test Programs", description: "1. Run program\n1. Check results\n1. Fix code" }
        ],
        students: [ :acain, :ajones ]
      },
    }

    # Collection of weekdays
    days = %w[Monday Tuesday Wednesday Thursday Friday]

    puts "----> Create TaskStatus"
    TaskStatus.create(name:  "Not Started", description:  "You have not yet started this task.")
    TaskStatus.create(name:  "Complete", description:  "This task has been signed off by your tutor.")
    TaskStatus.create(name:  "Need Help", description:  "Some help is required in order to complete this task.")
    TaskStatus.create(name:  "Working On It", description:  "This task is currently being worked on.")
    TaskStatus.create(name:  "Fix and Resubmit", description:  "This task must be resubmitted after fixing some issues.")
    TaskStatus.create(name:  "Fix and Include", description:  "This task must be fixed and included in your portfolio, but should not be resubmitted.")
    TaskStatus.create(name:  "Redo", description:  "This task needs to be redone.")
    TaskStatus.create(name:  "Discuss", description:  "Your work looks good, discuss it with your tutor to complete.")
    TaskStatus.create(name:  "Ready to Mark", description:  "This task is ready for the tutor to assess to provide feedback.")
    TaskStatus.create(name:  "Demonstrate", description:  "Your work looks good, demonstrate it to your tutor to complete.")
    TaskStatus.create(name:  "Fail", description:  "You did not successfully demonstrate the required learning in this task.")

    user_cache = {}

    # Create users
    puts "----> Adding users"
    users.each do |user_key, profile|
      username = user_key.to_s

      profile[:role_id] ||= Role.student_id
      profile[:email]       ||= "#{username}@doubtfire.com"
      profile[:username]    ||= username

      user = User.create!(profile.merge({password: 'password', password_confirmation: 'password'}))
      user_cache[user_key] = user
    end

    # Function to find or create students
    find_or_create_student = lambda { |username|
      if user_cache.has_key?(username)
        return user_cache[username]
      else
        profile = {
          first_name:   Faker::Name.first_name,
          last_name:    Faker::Name.last_name,
          nickname:     username,
          role_id:  Role.student_id,
          email:        "#{username}@doubtfire.com",
          username:     username,
          password:     'password',
          password_confirmation: 'password'
        }

        user = User.create!(profile)
        user_cache[username] = user
        return user
      end
    }

    # print "----> Adding Students "
    # 1000.times do | count |
    #   username = "student_#{count}"

    #   if count % 100 == 0
    #     print '.'
    #   end

    #   profile = {
    #     first_name:   Faker::Name.first_name,
    #     last_name:    Faker::Name.last_name,
    #     nickname:     "stud_#{count}",
    #     system_role:  'basic',
    #     email:        "#{username}@doubtfire.com",
    #     username:     username,
    #     password:     'password',
    #     password_confirmation: 'password',
    #   }

    #   user = User.create!(profile)
    #   user_cache[username] = user
    # end
    # puts '!'


    puts "----> Adding Units"
    # Create projects (units) for each of the values in unit_data
    unit_data.each do | unit_key, unit_details |
      puts "------> #{unit_details[:code]}"
      unit = Unit.create!(
        code: unit_details[:code],
        name: unit_details[:name],
        description: Populator.words(10..15),
        start_date: Time.zone.now  - 6.weeks,
        end_date: 13.weeks.since(Time.zone.now - 6.weeks)
      )

      puts "--------> #{unit_details[:num_tasks]} tasks"
      # Create tasks for unit
      unit_details[:num_tasks].times do |count|
        up_reqs = []
        rand(1..4).times.each_with_index do | file, idx |
          up_reqs[idx] = { :key => "file#{idx}", :name => Populator.words(1..3).capitalize, :type => ["code", "document", "image"].sample }
        end
        puts "----------> task #{count} has #{up_reqs.length} files to upload"
        target_date = unit.start_date + ((count + 1) % 12).weeks # Assignment 6 due week 6, etc.
        start_date = target_date - rand(1.0..2.0).weeks
        TaskDefinition.create(
          name: "Assignment #{count + 1}",
          abbreviation: "A#{count + 1}",
          unit_id: unit.id,
          description: Populator.words(5..10),
          weighting: BigDecimal.new("2"),
          target_date: target_date,
          upload_requirements: up_reqs.to_json,
          start_date: start_date
        )
      end

      puts "--------> Adding ILOs"
      unit_details[:ilos].each do |ilo_params|
        ilo_params['unit_id'] = unit.id
        LearningOutcome.create!(ilo_params)
      end

      # Create convenor roles
      unit_details[:convenors].each do | user_key |
        unit.employ_staff(user_cache[user_key], Role.convenor)
      end

      student_count = 0
      tutorial_count = 0

      # Create tutorials and enrol students
      unit_details[:tutors].each do | user_details |
        #only up to 4 tutorials for small scale
        if tutorial_count > max_tutorials then break end

        tutor = user_cache[user_details[:user]]
        puts "--------> Tutor #{tutor.name}"
        tutor_unit_role = unit.employ_staff(tutor, Role.tutor)

        print "---------> #{user_details[:num]} tutorials"
        user_details[:num].times do | count |
          tutorial_count += 1
          #day, time, location, tutor_username, abbrev
          tutorial = unit.add_tutorial(
            "#{days.sample}",
            "#{8 + rand(12)}:#{['00', '30'].sample}",    # Mon-Fri 8am-7:30pm
            "#{['EN', 'BA'].sample}#{rand(7)}#{rand(1)}#{rand(9)}", # EN###/BA###
            tutor,
            "LA1-#{tutorial_count.to_s.rjust(2, '0')}"
          )

          # Add a random number of students to the tutorial
          (min_students + rand(delta_students)).times do
            proj = unit.enrol_student(find_or_create_student.call("student_#{student_count}"), tutorial.id)
            student_count += 1
          end

          print '.'

          # Add fixed students to first tutorial
          if count == 0
            unit_details[:students].each do | student_key |
              unit.enrol_student(user_cache[student_key], tutorial.id)
            end
          end
        end
        puts "!"
      end #tutorial
    end #unit
    # Run simulate signoff?
    puts "----> Would you like to simulate student progress? This may take a while... [y/n]"
    if STDIN.gets.chomp.downcase == 'y'
      puts "----> Simulating signoff..."
      Rake::Task["db:simulate_signoff"].execute
      puts "----> Updating student progress..."
      Rake::Task["submission:update_progress"].execute
    end
    puts "----> Done."
  end
end
