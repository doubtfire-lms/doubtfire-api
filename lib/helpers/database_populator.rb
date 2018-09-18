require 'populator'
require 'faker'
require 'bcrypt'
require 'json'
require_all 'lib/helpers'

#
# This class populates data in the database
#
class DatabasePopulator
  #
  # Initialiser sets up the cache required for the populator.
  # Scale is set to :small by default.
  #
  def initialize(scale = :small)
    # Set up our caches
    scale ||= :small
    @user_cache = {}
    @unit_cache = {}
    @task_def_cache = {}
    # Set up the scale
    scale_data = {
      small: {
        min_students: 5,
        delta_students: 2,
        few_tasks: 5,
        some_tasks: 10,
        many_tasks: 20,
        few_tutorials: 1,
        some_tutorials: 1,
        many_tutorials: 1,
        max_tutorials: 4,
        tickets_generated: 10
      },
      large: {
        min_students: 15,
        delta_students: 7,
        few_tasks: 10,
        some_tasks: 30,
        many_tasks: 50,
        few_tutorials: 1,
        some_tutorials: 2,
        many_tutorials: 4,
        max_tutorials: 20,
        tickets_generated: 50
      }
    }
    accepted_scale_types = scale_data.keys
    unless accepted_scale_types.include?(scale)
      throw "Invalid scale value '#{scale}'. Acceptable values are: #{accepted_scale_types.join(", ")}"
    else
      puts "-> Scale is set to #{scale}"
    end
    @scale = scale_data[scale]
    
    generate_user_roles
    generate_task_statuses
    
    # Fixed data contains all fixed units and users created
    generate_fixed_data()
  end

  def generate_admin
    @user_data = {
      acain: { first_name: 'Andrew', last_name: 'Cain', nickname: 'Macite', role_id: Role.admin_id }
    }
  end
  #
  # Generate some users. Pass in an optional filter(s) for:
  # Role.admin, Role.convenor, Role.tutor, Role.student
  #
  def generate_users(filter = nil)
    accepted_roles = Role.all

    if filter.nil?
      filter = accepted_roles
    elsif accepted_roles.include? filter
      filter_ids = [filter].flatten.map(&:id)
      filter = Role.where(id: filter_ids)
    else
      accepted_to_str = Role.all.pluck(:name).map { | s | "Role." << s.downcase }
      throw "Unaccepted filter for generate_users, should be one of #{accepted_to_str}"
    end

    print "--> Generating users with role(s) #{filter.pluck(:name).join(', ')}"
    users_to_generate = @user_data.select { | user_key, profile | filter.pluck(:id).include? profile[:role_id] }

    # Create each user
    users_to_generate.each do |user_key, profile|
      print '.'
      username = user_key.to_s

      profile[:email]     ||= "#{username}@doubtfire.com"
      profile[:username]  ||= username
      profile[:login_id]  ||= username

      if AuthenticationHelpers.aaf_auth?
        user = User.create!(profile)
      else
        user = User.create!(profile.merge({
          password: 'password',
          password_confirmation: 'password'
        }))
      end

      @user_cache[user_key] = user
    end
    puts '!'
  end

  #
  # Generates some units
  #
  def generate_units
    puts "--> Generating units"

    if @user_cache.empty?
      # Must generate users first!
      puts "---> No users generated. Generating users first..."
      generate_users()
    end

    # Set sizes from scale
    some_tasks = @scale[:some_tasks]
    many_tasks = @scale[:many_tasks]
    some_tutorials = @scale[:some_tutorials]
    many_tutorials = @scale[:many_tutorials]

    # Run through the unit_details and initialise their data
    @unit_data.each do | unit_key, unit_details |
      puts "---> Generating unit #{unit_details[:code]}"
      unit = Unit.create!(
        code: unit_details[:code],
        name: unit_details[:name],
        description: faker_random_sentence(10, 15),
        start_date: Time.zone.now  - 6.weeks,
        end_date: 13.weeks.since(Time.zone.now - 6.weeks)
      )
      # Assign the convenors for this unit
      unit_details[:convenors].each do | user_key |
        puts "----> Adding convenor #{user_key}"
        unit.employ_staff(@user_cache[user_key], Role.convenor)
      end
      # Cache what we have
      @unit_cache[unit_key] = unit
      # Generate other unit-related stuff
      generate_tasks_for_unit(unit, unit_details)
      generate_and_align_ilos_for_unit(unit, unit_details)
      generate_tutorials_and_enrol_students_for_unit(unit, unit_details)
    end
  end

  #
  # Random project helper
  #
  def random_project
    id = Project.pluck(:id).sample
    Project.find(id)
  end

  #
  # Generated fixed data here for students and units
  #
  def generate_fixed_data
    # Define fixed user data here
    @user_data = {
      acain:              {first_name: "Andrew",  last_name: "Cain",          nickname: "Macite",         role_id: Role.admin_id },
      aconvenor:          {first_name: "Clinton", last_name: "Woodward",      nickname: "The Giant",      role_id: Role.convenor_id },
      aadmin:             {first_name: "Allan",   last_name: "Jones",         nickname: "P-Jiddy",        role_id: Role.admin_id },
      rwilson:            {first_name: "Reuben",  last_name: "Wilson",        nickname: "Reubs",          role_id: Role.convenor_id },
      atutor:             {first_name: "Akihiro", last_name: "Noguchi",       nickname: "Animations",     role_id: Role.tutor_id },
      acummaudo:          {first_name: "Alex",    last_name: "Cummaudo",      nickname: "DoubtfireDude",  role_id: Role.convenor_id },
      cliff:              {first_name: "Cliff",   last_name: "Warren",        nickname: "Cliff",          role_id: Role.tutor_id },
      joostfunkekupper:   {first_name: "Joost",   last_name: "Funke Kupper",  nickname: "Joe",            role_id: Role.tutor_id },
      angusmorton:        {first_name: "Angus",   last_name: "Morton",        nickname: "Angus",          role_id: Role.tutor_id },
      "123456X" =>        {first_name: "Fred",    last_name: "Jones",         nickname: "Foo",            role_id: Role.student_id },
      astudent:           {first_name: "student", last_name: "surname",       nickname: "Foo",            role_id: Role.student_id }
    }
    # Add 10 tutors to fixed info
    10.times do |count|
      tutor_name = "tutor_#{count}";
      @user_data[tutor_name] = {
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        nickname: tutor_name,
        role_id: Role.tutor_id
      }
    end
    # Define fixed unit details here
    many_tutorials = @scale[:many_tutorials]
    some_tutorials = @scale[:some_tutorials]
    few_tutorials  = @scale[:few_tutorials]
    some_tasks     = @scale[:some_tasks]
    many_tasks     = @scale[:many_tasks]
    few_tasks      = @scale[:few_tasks]
    @unit_data = {
      intro_prog: {
        code: "COS10001",
        name: "Introduction to Programming",
        convenors: [ :acain, :aconvenor ],
        tutors: [
          { user: :acain, num: many_tutorials },
          { user: :aconvenor, num: many_tutorials },
          { user: :aadmin, num: many_tutorials },
          { user: :rwilson, num: many_tutorials },
          { user: :acummaudo, num: some_tutorials },
          { user: :atutor, num: many_tutorials },
          { user: :joostfunkekupper, num: many_tutorials },
          { user: :angusmorton, num: some_tutorials },
          { user: :cliff, num: some_tutorials },
        ],
        num_tasks: some_tasks,
        ilos: Faker::Number.between(0,3),
        students: [ ]
      },
      oop: {
        code: "COS20007",
        name: "Object Oriented Programming",
        convenors: [ :acain, :aconvenor, :aadmin, :acummaudo ],
        tutors: [
          { user: "tutor_1", num: few_tutorials },
          { user: :angusmorton, num: few_tutorials },
          { user: :atutor, num: few_tutorials },
          { user: :joostfunkekupper, num: few_tutorials },
        ],
        num_tasks: many_tasks,
        ilos: Faker::Number.between(0,3),
        students: [ :cliff ]
      },
      ai4g: {
        code: "COS30046",
        name: "Artificial Intelligence for Games",
        convenors: [ :aconvenor ],
        tutors: [
          { user: :aconvenor, num: few_tutorials },
          { user: :cliff, num: few_tutorials },
        ],
        num_tasks: few_tasks,
        ilos: Faker::Number.between(0,3),
        students: [ :acummaudo ]
      },
      gameprog: {
        code: "COS30243",
        name: "Game Programming",
        convenors: [ :aconvenor, :acummaudo ],
        tutors: [
          { user: :aconvenor, num: few_tutorials },
        ],
        num_tasks: few_tasks,
        ilos: Faker::Number.between(0,3),
        students: [ :acain, :aadmin ]
      },
    }
    puts "-> Defined #{@user_data.length} fixed users and #{@unit_data.length} units"
  end

  private

  #
  # Generate roles
  #
  def generate_user_roles
    print "-> Generating user roles"
    roles = [
      { name: 'Student', description: "Students are able to be enrolled into units, and to submit progress for their unit projects." },
      { name: 'Tutor', description: "Tutors are able to supervise tutorial classes and provide feedback to students, they may also be students in other units" },
      { name: 'Convenor', description: "Convenors are able to create and manage units, as well as act as tutors and students." },
      { name: 'Admin', description: "Admin are able to create convenors, and act as convenors, tutors, and students in units." }
    ]

    roles.each do |role|
      Role.create!(name: role[:name], description: role[:description])
      print "."
    end
    puts "!"
  end

  #
  # Generate tasks statuses
  #
  def generate_task_statuses
    print "-> Generating task statuses"
    statuses = {
      "Not Started": "You have not yet started this task.",
      "Complete": "This task has been signed off by your tutor.",
      "Need Help": "Some help is required in order to complete this task.",
      "Working On It": "This task is currently being worked on.",
      "Fix and Resubmit": "This task must be resubmitted after fixing some issues.",
      "Do Not Resubmit": "This task must be fixed and included in your portfolio, but should not be resubmitted.",
      "Redo": "This task needs to be redone.",
      "Discuss": "Your work looks good, discuss it with your tutor to complete.",
      "Ready to Mark": "This task is ready for the tutor to assess to provide feedback.",
      "Demonstrate": "Your work looks good, demonstrate it to your tutor to complete.",
      "Fail": "You did not successfully demonstrate the required learning in this task.",
      "Time Exceeded": "You did not submit or complete the task before the appropriate deadline."
    }
    statuses.each do | name, desc |
      print "."
      TaskStatus.create(name: name, description: desc)
    end
    puts "!"
  end

  #
  # Generates tasks for the given unit
  #
  def generate_tasks_for_unit(unit, unit_details)
    print "----> Generating #{unit_details[:num_tasks]} tasks"
    unit_details[:num_tasks].times do |count|
      up_reqs = []
      Faker::Number.between(1,4).times.each_with_index do | file, idx |
        up_reqs[idx] = {:key => "file#{idx}", :name => faker_random_sentence(1, 3).capitalize, :type => ["code", "document", "image"].sample }
      end
      target_date = unit.start_date + ((count + 1) % 12).weeks # Assignment 6 due week 6, etc.
      start_date = target_date - Faker::Number.between(1.0,2.0).weeks
      # Make sure at least 30% of the tasks are pass
      target_grade = @task_def_cache.length > (unit_details[:num_tasks] / 3) ? Faker::Number.between(0,3) : 0
      task_def = TaskDefinition.create(
        name: "Assignment #{count + 1}",
        abbreviation: "A#{count + 1}",
        unit_id: unit.id,
        description: faker_random_sentence(5, 10),
        weighting: BigDecimal.new("2"),
        target_date: target_date,
        upload_requirements: up_reqs.to_json,
        start_date: start_date,
        target_grade: target_grade
      )
      @task_def_cache[task_def.id] = task_def
      print "."
    end
    puts "!"
  end

  #
  # Generates ILOs and aligns ILOs to tasks for unit
  #
  def generate_and_align_ilos_for_unit(unit, unit_details)
    if @task_def_cache.empty?
      throw "Task definition cache is empty. Call generate_tasks_for_unit unit_key, first before calling generate_and_align_ilos_for_unit"
    end

    # Create the ILOs
    print "----> Adding #{unit_details[:ilos]} ILOs"
    ilo_cache = {}
    unit_details[:ilos].times do |index|
      ilo_number = index + 1
      ilo = LearningOutcome.create!(
        unit_id: unit.id,
        ilo_number: ilo_number,
        abbreviation: "ILO#{ilo_number}",
        name: faker_random_sentence(1, 4).capitalize,
        description:  faker_random_sentence(10, 15)
      )
      ilo_cache[ilo.id] = ilo
      print "."
    end
    puts "!"

    # Align each of the ILOs to a task
    if unit_details[:ilos] > 0
      print "----> Aligning tasks to ILOs"
      20.times do
        ilo_id = unit.learning_outcomes.pluck('id').sample
        task_def_id = unit.task_definition_ids.sample
        link = LearningOutcomeTaskLink.find_or_create_by(
          task_definition_id: task_def_id,
          learning_outcome_id: ilo_id,
          task_id: nil
        )
        link.rating = Faker::Number.between(1,4)
        link.description = faker_random_sentence(5, 10)
        link.save!
        print '.'
      end
      puts '!'
    end
  end

  #
  # Generates tutorials for unit and enrols some students in them
  #
  def generate_tutorials_and_enrol_students_for_unit(unit, unit_details)
    student_count  = 0
    tutorial_count = 0

    # Grab stuff from scale
    max_tutorials  = @scale[:max_tutorials]
    min_students   = @scale[:min_students]
    delta_students = @scale[:delta_students]

    # Collection of weekdays to be used
    weekdays = %w[Monday Tuesday Wednesday Thursday Friday]

    # Create tutorials and enrol students
    unit_details[:tutors].each do | user_details |
      # only up to 4 tutorials for small scale
      if tutorial_count > max_tutorials then break end

      tutor = @user_cache[user_details[:user]]
      puts "----> Enrolling tutor #{tutor.name} with #{user_details[:num]} tutorials"
      tutor_unit_role = unit.employ_staff(tutor, Role.tutor)

      user_details[:num].times do | count |
        tutorial_count += 1
        #day, time, location, tutor_username, abbrev
        tutorial = unit.add_tutorial(
          "#{weekdays.sample}",
          "#{8 + Faker::Number.between(0,11)}:#{['00', '30'].sample}",    # Mon-Fri 8am-7:30pm
          "#{['EN', 'BA'].sample}#{Faker::Number.between(0,6)}0#{Faker::Number.between(0,8)}", # EN###/BA###
          tutor,
          "LA1-#{tutorial_count.to_s.rjust(2, '0')}"
        )

        # Add a random number of students to the tutorial
        num_students_in_tutorial = (min_students + Faker::Number.between(0,delta_students - 1))
        print "-----> Creating #{num_students_in_tutorial} projects under tutorial #{tutorial.abbreviation}"
        num_students_in_tutorial.times do
          student = find_or_create_student("student_#{student_count}")
          project = unit.enrol_student(student, tutorial.id)
          student_count += 1
          print '.'
        end
        # Add fixed students to first tutorial
        if count == 0
          unit_details[:students].each do | student_key |
            unit.enrol_student(@user_cache[student_key], tutorial.id)
          end
        end
        puts "!"
      end
    end
  end
end
