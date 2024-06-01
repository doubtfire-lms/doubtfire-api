if Rails.env.development?
  require 'faker'
end
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
    @user_cache = nil
    @echo = false
    @unit_cache = {}
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
        max_tutorials: 4
      },
      large: {
        min_students: 50,
        delta_students: 7,
        few_tasks: 10,
        some_tasks: 30,
        many_tasks: 50,
        few_tutorials: 1,
        some_tutorials: 2,
        many_tutorials: 4,
        max_tutorials: 20
      }
    }
    accepted_scale_types = scale_data.keys
    unless accepted_scale_types.include?(scale)
      throw "Invalid scale value '#{scale}'. Acceptable values are: #{accepted_scale_types.join(", ")}"
    end
    @scale = scale_data[scale]

    return if User.count > 1

    echo_line "-> Scale is set to #{scale}"

    @user_cache = {}
    @echo = true

    # Fixed data contains all fixed units and users created
    generate_fixed_data()

    generate_teaching_periods()
    generate_campuses
    generate_activity_types
  end

  def generate_teaching_periods
    data = {
      period: 'T1',
      year: 2018,
      start_date: Date.parse('2018-03-05'),
      end_date: Date.parse('2018-05-25'),
      active_until: Date.parse('2018-06-15')
    }
    tp = TeachingPeriod.create!(data)

    tp.add_break Date.parse('2018-03-30'), 1

    data = {
      period: 'T2',
      year: 2018,
      start_date: Date.parse('2018-07-09'),
      end_date: Date.parse('2018-09-28'),
      active_until: Date.parse('2018-10-19')
    }
    tp = TeachingPeriod.create! data

    tp.add_break Date.parse('2018-08-13'), 1

    data = {
      period: 'T3',
      year: 2018,
      start_date: Date.parse('2018-11-05'),
      end_date: Date.parse('2019-02-01'),
      active_until: Date.parse('2019-02-15')
    }
    tp = TeachingPeriod.create! data

    tp.add_break Date.parse('2018-12-24'), 2
  end

  def generate_campuses
    data = {
      name: 'Online',
      mode: 'timetable',
      abbreviation: 'C',
      active: true
    }
    Campus.create! data

    data = {
      name: 'Burwood',
      mode: 'automatic',
      abbreviation: 'B',
      active: true
    }
    Campus.create! data

    data = {
      name: 'Geelong',
      mode: 'manual',
      abbreviation: 'G',
      active: true
    }
    Campus.create! data
  end

  def generate_activity_types
    data = {
      name: 'Practical',
      abbreviation: 'prac',
    }
    ActivityType.create! data

    data = {
      name: 'Workshop',
      abbreviation: 'wrkshop',
    }
    ActivityType.create! data

    data = {
      name: 'Class',
      abbreviation: 'cls',
    }
    ActivityType.create! data
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
      accepted_to_str = Role.all.pluck(:name).map { |s| "Role." << s.downcase }
      throw "Unaccepted filter for generate_users, should be one of #{accepted_to_str}"
    end

    echo "--> Generating users with role(s) #{filter.pluck(:name).join(', ')}"
    users_to_generate = @user_data.select { |user_key, profile| filter.pluck(:id).include? profile[:role_id] }

    # Create each user
    users_to_generate.each do |user_key, profile|
      echo '.'
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
    echo_line '!'
  end

  #
  # Generates some units
  #
  def generate_units
    echo_line "--> Generating units"

    if @user_cache.empty?
      # Must generate users first!
      echo_line "---> No users generated. Generating users first..."
      generate_users()
    end

    # Set sizes from scale
    some_tasks = @scale[:some_tasks]
    many_tasks = @scale[:many_tasks]
    some_tutorials = @scale[:some_tutorials]
    many_tutorials = @scale[:many_tutorials]

    # Run through the unit_details and initialise their data
    @unit_data.each do |unit_key, unit_details|
      echo_line "---> Generating unit #{unit_details[:code]}"

      if unit_details[:teaching_period].present?
        data = {
          code: unit_details[:code],
          name: unit_details[:name],
          description: faker_random_sentence(10, 15),
          teaching_period: unit_details[:teaching_period]
        }
      else
        data = {
          code: unit_details[:code],
          name: unit_details[:name],
          description: faker_random_sentence(10, 15),
          start_date: Time.zone.now - 6.weeks,
          end_date: 13.weeks.since(Time.zone.now - 6.weeks)
        }
      end

      unit = Unit.create!(
        data
      )
      # Assign the convenors for this unit
      unit_details[:convenors].each do |user_key|
        echo_line "----> Adding convenor #{user_key}"
        unit.employ_staff(@user_cache[user_key], Role.convenor)
      end
      # Cache what we have
      @unit_cache[unit_key] = unit
      # Generate other unit-related stuff
      generate_tasks_for_unit(unit, unit_details)
      generate_and_align_ilos_for_unit(unit, unit_details)
      generate_tutorial_streams_for(unit)
      generate_tutorials_and_enrol_students_for_unit(unit, unit_details)
    end
  end

  def generate_tutorial_streams_for(unit)
    rand(1...5).times {
      activity_type = random_activity_type
      name = "#{activity_type.name}-#{unit.tutorial_streams.where(activity_type: activity_type).count + 1}"
      abbreviation = "#{activity_type.abbreviation}-#{unit.tutorial_streams.where(activity_type: activity_type).count + 1}"
      unit.add_tutorial_stream(name, abbreviation, activity_type)
    }
  end

  #
  # Random project helper
  #
  def random_project
    id = Project.pluck(:id).sample
    Project.find(id)
  end

  #
  # Random campus helper
  #
  def random_campus
    id = Campus.pluck(:id).sample
    Campus.find(id)
  end

  #
  # Random activity type helper
  #
  def random_activity_type
    id = ActivityType.pluck(:id).sample
    ActivityType.find(id)
  end

  #
  # Generated fixed data here for students and units
  #
  def generate_fixed_data
    # Define fixed user data here
    @user_data = {
      acain: { first_name: "Andrew", last_name: "Cain", nickname: "Macite", role_id: Role.admin_id },
      aauditor: { first_name: "Auditor", last_name: "Auditor", nickname: "Auditor", role_id: Role.auditor_id },
      aconvenor: { first_name: "Clinton", last_name: "Woodward", nickname: "The Giant", role_id: Role.convenor_id },
      ajones: { first_name: "Allan", last_name: "Jones", nickname: "P-Jiddy", role_id: Role.admin_id },
      rwilson: { first_name: "Reuben", last_name: "Wilson", nickname: "Reubs", role_id: Role.convenor_id },
      atutor: { first_name: "Akihiro", last_name: "Noguchi", nickname: "Animations", role_id: Role.tutor_id },
      acummaudo: { first_name: "Alex", last_name: "Cummaudo", nickname: "DoubtfireDude", role_id: Role.convenor_id },
      cliff: { first_name: "Cliff",   last_name: "Warren", nickname: "Cliff", role_id: Role.tutor_id },
      joostfunkekupper: { first_name: "Joost",   last_name: "Funke Kupper", nickname: "Joe", role_id: Role.tutor_id },
      angusmorton: { first_name: "Angus",   last_name: "Morton",        nickname: "Angus",          role_id: Role.tutor_id },
      "123456X" => { first_name: "Fred",    last_name: "Jones",         nickname: "Foo",            role_id: Role.student_id },
      astudent: { first_name: "student", last_name: "surname", nickname: "Foo", role_id: Role.student_id }
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
        convenors: [:acain, :aconvenor],
        teaching_period: TeachingPeriod.first,
        tutors: [
          { user: :acain, num: many_tutorials },
          { user: :aconvenor, num: many_tutorials },
          { user: :ajones, num: many_tutorials },
          { user: :rwilson, num: many_tutorials },
          { user: :acummaudo, num: some_tutorials },
          { user: :atutor, num: many_tutorials },
          { user: :joostfunkekupper, num: many_tutorials },
          { user: :angusmorton, num: some_tutorials },
          { user: :cliff, num: some_tutorials },
        ],
        students: []
      },
      oop: {
        code: "COS20007",
        name: "Object Oriented Programming",
        convenors: [:acain, :aconvenor, :ajones, :acummaudo],
        tutors: [
          { user: "tutor_1", num: few_tutorials },
          { user: :angusmorton, num: few_tutorials },
          { user: :atutor, num: few_tutorials },
          { user: :joostfunkekupper, num: few_tutorials },
        ],
        num_tasks: many_tasks,
        ilos: Faker::Number.between(from: 0, to: 3),
        students: [:cliff]
      },
      ai4g: {
        code: "COS30046",
        name: "Artificial Intelligence for Games",
        convenors: [:aconvenor],
        tutors: [
          { user: :aconvenor, num: few_tutorials },
          { user: :cliff, num: few_tutorials },
        ],
        num_tasks: few_tasks,
        ilos: Faker::Number.between(from: 0, to: 3),
        students: [:acummaudo]
      },
      gameprog: {
        code: "COS30243",
        name: "Game Programming",
        convenors: [:aconvenor, :acummaudo],
        tutors: [
          { user: :aconvenor, num: few_tutorials },
        ],
        num_tasks: few_tasks,
        ilos: Faker::Number.between(from: 0, to: 3),
        students: [:acain, :ajones]
      },
    }
    echo_line "-> Defined #{@user_data.length} fixed users and #{@unit_data.length} units"
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
    unit_details[:tutors].each do |user_details|
      # only up to 4 tutorials for small scale
      break if tutorial_count > max_tutorials

      if @user_cache.present?
        tutor = @user_cache[user_details[:user]]
      else
        tutor = User.find_by_username(user_details[:user])
      end

      echo_line "----> Enrolling tutor #{tutor.name} with #{user_details[:num]} tutorials"
      tutor_unit_role = unit.employ_staff(tutor, Role.tutor)

      campus = random_campus

      user_details[:num].times do |count|
        tutorial_count += 1
        tutorial_stream = unit.tutorial_streams.sample
        # day, time, location, tutor_username, abbrev
        tutorial = unit.add_tutorial(
          "#{weekdays.sample}",
          "#{8 + Faker::Number.between(from: 0, to: 11)}:#{['00', '30'].sample}", # Mon-Fri 8am-7:30pm
          "#{['EN', 'BA'].sample}#{Faker::Number.between(from: 0, to: 6)}0#{Faker::Number.between(from: 0, to: 8)}", # EN###/BA###
          tutor,
          campus,
          rand(10...20),
          "LA1-#{tutorial_count.to_s.rjust(2, '0')}",
          tutorial_stream
        )

        # Add a random number of students to the tutorial
        num_students_in_tutorial = (min_students + Faker::Number.between(from: 0, to: delta_students - 1))
        echo "-----> Creating #{num_students_in_tutorial} projects under tutorial #{tutorial.abbreviation}"
        num_students_in_tutorial.times do
          student = find_or_create_student("student_#{student_count}")
          project = unit.enrol_student(student, campus)
          student_count += 1
          project.enrol_in(tutorial)
          echo '.'
        end
        # Add fixed students to first tutorial
        if count == 0
          unit_details[:students].each do |student_key|
            unit.enrol_student(@user_cache[student_key], campus)
          end
        end
        echo_line "!"
      end
    end
  end

  def self.assess_task(proj, task, tutor, status, complete_date)
    alignments = []
    task.unit.learning_outcomes.each do |lo|
      next if rand(0..10) < 7

      data = {
        ilo_id: lo.id,
        rating: rand(1..5),
        rationale: "Simulated rationale text..."
      }
      alignments << data
    end

    if task.group_task? && task.group.nil?
      return
    end

    contributions = nil

    task.create_alignments_from_submission(alignments) unless alignments.nil?
    task.create_submission_and_trigger_state_change(proj.student) # , propagate = true, contributions = contributions, trigger = trigger)
    task.assess status, tutor, complete_date

    if task.task_definition.is_graded?
      task.grade_task rand(-1..3)
    end

    if task.for_definition_with_quality?
      task.update(quality_pts: rand(0..task.task_definition.max_quality_pts))
    end

    pdf_path = task.final_pdf_path
    if pdf_path && !File.exist?(pdf_path)
      FileUtils.ln_s(Rails.root.join('test_files', 'unit_files', 'sample-student-submission.pdf'), pdf_path)
    end

    task.portfolio_evidence_path = pdf_path
    task.save
  end

  def self.generate_portfolio(project)
    portfolio_tmp_dir = project.portfolio_temp_path
    FileUtils.mkdir_p(portfolio_tmp_dir)

    lsr_path = File.join(portfolio_tmp_dir, "000-document-LearningSummaryReport.pdf")
    FileUtils.ln_s(Rails.root.join('test_files', 'unit_files', 'sample-learning-summary.pdf'), lsr_path) unless File.exist? lsr_path
    project.compile_portfolio = true
    project.create_portfolio
  end

  private

  # Output
  def echo *args
    print(*args) if @echo
  end

  def echo_line *args
    puts(*args) if @echo
  end

  #
  # Generates tasks for the given unit
  #
  def generate_tasks_for_unit(unit, unit_details)
    echo "----> Generating #{unit_details[:num_tasks]} tasks"

    csv_to_import = Rails.root.join('test_files', "#{unit.code}-Tasks.csv")
    zip_to_import = Rails.root.join('test_files', "#{unit.code}-Tasks.zip")

    if (File.exist? csv_to_import) && (File.exist? zip_to_import)
      echo "----> CSV file found, importing tasks from #{csv_to_import} \n"
      result = unit.import_tasks_from_csv(File.open(csv_to_import))
      unless result[:errors].empty?
        raise("----> Task import from CSV failed with the following errors: #{result[:errors]} \n")
      end

      echo "----> Importing task files from #{zip_to_import} \n"
      result = unit.import_task_files_from_zip zip_to_import
      unless result[:errors].empty?
        raise("----> Task files import failed with the following errors: #{result[:errors]} \n")
      end

      unless result[:ignored].empty?
        echo "----> Task files import ignored the following files: #{result[:ignored]} \n"
      end

      return
    end

    unit_details[:num_tasks].times do |count|
      up_reqs = []
      Faker::Number.between(from: 1, to: 4).times.each_with_index do |file, idx|
        up_reqs[idx] = { :key => "file#{idx}", :name => faker_random_sentence(1, 3).capitalize, :type => ["code", "document", "image"].sample }
      end
      target_date = unit.start_date + ((count + 1) % 12).weeks # Assignment 6 due week 6, etc.
      start_date = target_date - Faker::Number.between(from: 1.0, to: 2.0).weeks
      # Make sure at least 30% of the tasks are pass
      target_grade = Faker::Number.between(from: 0, to: 3)
      task_def = TaskDefinition.create(
        name: "Assignment #{count + 1}",
        abbreviation: "A#{count + 1}",
        unit_id: unit.id,
        description: faker_random_sentence(5, 10),
        weighting: BigDecimal("2"),
        target_date: target_date,
        upload_requirements: up_reqs.to_json,
        start_date: start_date,
        target_grade: target_grade
      )
      echo "."
    end
    echo_line "!"
  end

  #
  # Generates ILOs and aligns ILOs to tasks for unit
  #
  def generate_and_align_ilos_for_unit(unit, unit_details)
    # Create the ILOs
    echo "----> Adding #{unit_details[:ilos]} ILOs"

    if File.exist? Rails.root.join('test_files', "#{unit.code}-Outcomes.csv")
      unit.import_outcomes_from_csv File.open(Rails.root.join('test_files', "#{unit.code}-Outcomes.csv"))
      unit.import_task_alignment_from_csv File.open(Rails.root.join('test_files', "#{unit.code}-Alignment.csv")), nil
      return
    end

    ilo_cache = {}
    unit_details[:ilos].times do |index|
      ilo_number = index + 1
      ilo = LearningOutcome.create!(
        unit_id: unit.id,
        ilo_number: ilo_number,
        abbreviation: "ILO#{ilo_number}",
        name: faker_random_sentence(1, 4).capitalize,
        description: faker_random_sentence(10, 15)
      )
      ilo_cache[ilo.id] = ilo
      echo "."
    end
    echo_line "!"

    # Align each of the ILOs to a task
    if unit_details[:ilos] > 0
      echo "----> Aligning tasks to ILOs"
      20.times do
        ilo_id = unit.learning_outcomes.pluck('id').sample
        task_def_id = unit.task_definition_ids.sample
        link = LearningOutcomeTaskLink.find_or_create_by(
          task_definition_id: task_def_id,
          learning_outcome_id: ilo_id,
          task_id: nil
        )
        link.rating = Faker::Number.between(from: 1, to: 4)
        link.description = faker_random_sentence(5, 10)
        link.save!
        echo '.'
      end
      echo_line '!'
    end
  end
end
