require 'csv'
require 'bcrypt'
require 'json'
require 'moss_ruby'

class Unit < ActiveRecord::Base
  include ApplicationHelper
  include FileHelper
  include LogHelper

  #
  # Permissions around unit data
  #
  def self.permissions
    # What can students do with units?
    student_role_permissions = [
      :get_unit
    ]
    # What can tutors do with units?
    tutor_role_permissions = [
      :get_unit,
      :get_students,
      :enrol_student,
      :provide_feedback,
      :download_stats,
      :download_unit_csv,
      :download_grades
    ]

    # What can convenors do with units?
    convenor_role_permissions = [
      :get_unit,
      :get_students,
      :enrol_student,
      :upload_csv,
      :download_unit_csv,
      :update,
      :employ_staff,
      :add_tutorial,
      :add_task_def,
      :provide_feedback,
      :change_project_enrolment,
      :download_stats,
      :download_grades
    ]

    # What can other users do with units?
    nil_role_permissions = [

    ]

    # Return permissions hash
    {
      :student  => student_role_permissions,
      :tutor    => tutor_role_permissions,
      :convenor => convenor_role_permissions,
      :nil      => nil_role_permissions
    }
  end

  def role_for(user)
    if convenors.where('unit_roles.user_id=:id', id: user.id).count == 1
      Role.convenor
    elsif tutors.where('unit_roles.user_id=:id', id: user.id).count == 1
      Role.tutor
    elsif students.where('projects.user_id=:id', id: user.id).count == 1
      Role.student
    else
      nil
    end
  end

  validates_presence_of :name, :description, :start_date, :end_date

  # Model associations.
  # When a Unit is destroyed, any TaskDefinitions, Tutorials, and ProjectConvenor instances will also be destroyed.
  has_many :task_definitions, -> { order "start_date ASC, abbreviation ASC" }, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :tutorials, dependent: :destroy
  has_many :unit_roles, dependent: :destroy
  has_many :learning_outcomes, dependent: :destroy
  has_many :tasks, through: :projects
  has_many :group_sets, dependent: :destroy

  has_many :learning_outcome_task_links, through: :task_definitions

  has_many :convenors, -> { joins(:role).where("roles.name = :role", role: 'Convenor') }, class_name: 'UnitRole'
  has_many :staff, ->     { joins(:role).where("roles.name = :role_convenor or roles.name = :role_tutor", role_convenor: 'Convenor', role_tutor: 'Tutor') }, class_name: 'UnitRole'

  scope :current,               ->{ current_for_date(Time.zone.now) }
  scope :current_for_date,      ->(date) { where("start_date <= ? AND end_date >= ?", date, date) }
  scope :not_current,           ->{ not_current_for_date(Time.zone.now) }
  scope :not_current_for_date,  ->(date) { where("start_date > ? OR end_date < ?", date, date) }
  scope :set_active,            ->{ where("active = ?", true) }
  scope :set_inactive,          ->{ where("active = ?", false) }

  def ordered_ilos()
    learning_outcomes.order(:ilo_number)
  end

  def task_outcome_alignments
    learning_outcome_task_links.where('task_id is NULL')
  end

  def student_tasks
    tasks.joins(:task_definition
        ).where("projects.enrolled = TRUE AND projects.target_grade >= task_definitions.target_grade")
  end

  def self.for_user_admin(user)
    if user.has_admin_capability?
      Unit.all
    else
      Unit.joins(:unit_roles).where('unit_roles.user_id = :user_id and unit_roles.role_id = :convenor_role', user_id: user.id, convenor_role: Role.convenor.id)
    end
  end

  def self.default
    unit = self.new

    unit.name         = "New Unit"
    unit.description  = "Enter a description for this unit."
    unit.start_date   = Date.today
    unit.end_date     = 13.weeks.from_now

    unit
  end

  #
  # Returns the tutors associated with this Unit
  # - includes convenor
  def tutors
    User.teaching(self)
  end

  def students
    projects
  end

  #
  # Last date/time of scan
  #
  def last_plagarism_scan
    if self[:last_plagarism_scan].nil?
      DateTime.new(2000,1,1)
    else
      self[:last_plagarism_scan]
    end
  end

  #
  # Returns the email of the first convenor or "acain@swin.edu.au" if there are no convenors
  #
  def convenor_email
    convenor = convenors.first
    if convenor
      convenor.user.email
    else
      "acain@swin.edu.au"
    end
  end

  def active_projects
    projects.where('enrolled = true')
  end

  # Adds a staff member for a role in a unit
  def employ_staff(user, role)
    old_role = unit_roles.where("user_id=:user_id", user_id: user.id).first
    return old_role if not old_role.nil?

    if (role != Role.student) && user.has_tutor_capability?
      new_staff = UnitRole.new
      new_staff.user_id = user.id
      new_staff.unit_id = id
      new_staff.role_id = role.id
      new_staff.save!
      new_staff
    end
  end

  # Adds a user to this project.
  def enrol_student(user, tutorial=nil)
    if tutorial.is_a?(Tutorial)
      tutorial_id = tutorial.id
    else
      tutorial_id = tutorial
    end

    # Validates that a student is not already assigned to the unit
    existing_project = projects.where("user_id=:user_id", user_id: user.id).first
    if existing_project
      if existing_project.enrolled == false
        existing_project.enrolled = true
        # If they are part of the unit, update their tutorial if supplied
        existing_project.tutorial_id = tutorial_id unless tutorial_id.nil?
        existing_project.save
      end

      return existing_project
    end

    # Validates that the tutorial exists for the unit
    if (not tutorial_id.nil?) && tutorials.where("id=:id", id: tutorial_id).count == 0
      return nil
    end

    project = Project.create!(
      user_id: user.id,
      unit_id: self.id,
      task_stats: "0.0|1.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0"
    )

    project.tutorial_id = tutorial_id unless tutorial_id.nil?
    project.save
    project
  end

  def update_project_stats
    active_projects.each { |p| p.calc_task_stats }
  end

  def tutorial_with_abbr(abbr)
    tutorials.where(abbreviation: abbr).first
  end

  #
  # Imports users into a project from CSV file.
  # Format: unit_code, Student ID,First Name,Surname,email,tutorial
  #
  def import_users_from_csv(file)
    tutorial_cache = {}
    success = []
    errors = []
    ignored = []

    CSV.foreach(file) do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /(subject|unit)_code/
      # next if row[5] !~ /^LA\d/

      begin
        unit_code, username  = row[0..1]
        first_name, last_name   = [row[2], row[3]].map{|name| name.titleize unless name.nil? }
        email, tutorial_code    = row[4..5]

        if unit_code != code
          ignored << { row: row, message: "Invalid unit code. #{unit_code} does not match #{code}" }
          next
        end

        if ! email =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
          errors << { row: row, message: "Invalid email address (#{email})" }
          next
        end

        username = username.downcase

        project_participant = User.find_or_create_by(username: username) {|new_user|
          new_user.first_name         = first_name
          new_user.last_name          = last_name
          new_user.nickname           = first_name
          new_user.role_id            = Role.student_id
          new_user.email              = email
          new_user.encrypted_password = BCrypt::Password.create("password")
        }

        if not project_participant.persisted?
          project_participant.password = "password"
          project_participant.save
        end

        #
        # Only import if a valid user - or if save worked
        #
        if project_participant.persisted?
          user_project = projects.where(user_id: project_participant.id).first

          tutorial = tutorial_cache[tutorial_code] || tutorial_with_abbr(tutorial_code)
          tutorial_cache[tutorial_code] ||= tutorial

          # Add the user to the project (if not already in there)
          if user_project.nil?
            if not tutorial.nil?
              enrol_student(project_participant, tutorial)
              success << { row: row, message: "Enrolled student with tutorial." }
            else
              enrol_student(project_participant)
              success << { row: row, message: "Enrolled student without tutorial." }
            end
          else
            # update tutorial
            changes = ""

            if user_project.tutorial != tutorial
              user_project.tutorial = tutorial
              user_project.save
              changes << "Changed tutorial. "
            end

            if not user_project.enrolled
              user_project.enrolled = true
              user_project.save
              changes << "Changed enrolment."
            end

            if changes.length == 0
              ignored << { row: row, message: "No change." }
            else
              success << { row: row, message: changes }
            end
          end
        else
          errors << { row: row, message: "Student record is invalid." }
        end
      rescue Exception => e
        errors << { row: row, message: e.message }
      end
    end

    {
      success: success,
      ignored: ignored,
      errors:  errors
    }
  end

  # Use the values in the CSV to set the enrolment of these
  # students to false for this unit.
  # CSV should contain just the usernames to withdraw
  def unenrol_users_from_csv(file)
    logger.info "Initiating withdraw of students from unit #{id} using CSV"

    success = []
    errors = []
    ignored = []

    CSV.parse(file, {
        :headers => true,
        :header_converters => [lambda { |i| i.nil? ? '' : i }, :downcase, lambda { |hdr| hdr.strip unless hdr.nil?}],
        :converters => [lambda{ |body| body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]
    }).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /(username)|(((unit)|(subject))_code)/
      # next if row[5] !~ /^LA\d/

      begin
        unit_code = row['unit_code']
        username  = row['username'].downcase unless row['username'].nil?

        if unit_code != code
          ignored << { row: row, message: "Invalid unit code. #{unit_code} does not match #{code}" }
          next
        end

        project_participant = User.where(username: username)

        if not project_participant
          errors << { row:row, message: "User #{username} not found" }
          next
        end
        if not project_participant.count == 1
          errors << { row:row, message: "User #{username} not found" }
          next
        end

        project_participant = project_participant.first

        user_project = projects.where(user_id: project_participant.id).first

        unless user_project
          ignored << { row:row, message: "User #{username} not enrolled in unit" }
          next
        end

        if user_project.enrolled
          user_project.enrolled = false
          user_project.save
          success << { row:row, message: "User #{username} withdrawn from unit" }
        else
          ignored << { row:row, message: "User #{username} not enrolled in unit" }
        end
      rescue Exception => e
        errors << { row: row, message: "Unexpected error: #{e.message}" }
      end
    end

    {
      success: success,
      ignored: ignored,
      errors:  errors
    }
  end

  def export_users_to_csv
    CSV.generate do |row|
      row << ["unit_code", "username", "first_name", "last_name", "email", "tutorial"]
      students.each do |project|
        row << [project.unit.code, project.student.username,  project.student.first_name, project.student.last_name, project.student.email, project.tutorial_abbr]
      end
    end
  end

  def export_learning_outcome_to_csv
    CSV.generate do |row|
      row << LearningOutcome.csv_header
      learning_outcomes.each do |outcome|
        outcome.add_csv_row row
      end
    end
  end

  def import_outcomes_from_csv(file)
    result = {
      success: [],
      errors: [],
      ignored: []
    }

    CSV.parse(file, {
        :headers => true,
        :header_converters => [lambda { |i| i.nil? ? '' : i }, :downcase, lambda { |hdr| hdr.strip unless hdr.nil?}],
        :converters => [lambda{ |body| body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]
    }).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/

      begin
        LearningOutcome.create_from_csv(self, row, result)
      rescue Exception => e
        result[:errors] << { row: row, message: "#{e.message}" }
      end
    end

    result
  end

  def export_task_alignment_to_csv
    LearningOutcomeTaskLink.export_task_alignment_to_csv(self, self)
  end

  # Use the values in the CSV to setup task alignments
  def import_task_alignment_from_csv(file, for_project)
    success = []
    errors = []
    ignored = []

    CSV.parse(file, {
        :headers => true,
        :header_converters => [lambda { |i| i.nil? ? '' : i }, :downcase, lambda { |hdr| hdr.strip unless hdr.nil?}],
        :converters => [lambda{ |body| body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]
    }).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/

      begin
        unit_code = row['unit_code']

        if unit_code != code
          ignored << { row: row, message: "Invalid unit code. #{unit_code} does not match #{code}" }
          next
        end

        outcome_abbr  = row['learning_outcome']
        outcome = learning_outcomes.where("abbreviation = :abbr", abbr: outcome_abbr).first

        if outcome.nil?
          errors << { row: row, message: "Unable to locate learning outcome with abbreviation #{outcome_abbr}" }
          next
        end

        task_def_abbr = row['task_abbr']
        task_def = task_definitions.where("abbreviation = :abbr", abbr: task_def_abbr).first

        if task_def.nil?
          errors << { row: row, message: "Unable to locate task with abbreviation #{task_def_abbr}" }
          next
        end

        rating = row['rating'].to_i
        description = row['description']

        if for_project.nil?
          link = LearningOutcomeTaskLink.find_or_create_by(task_definition_id: task_def.id, learning_outcome_id: outcome.id, task_id: nil)
        else
          task = for_project.tasks.where("task_definition_id = :tdid", tdid: task_def.id).first

          if task.nil?
            errors << { row: row, message: "Unable to locate task related to #{task_def_abbr}" }
            next
          end
          link = LearningOutcomeTaskLink.find_or_create_by(task_definition_id: task_def.id, learning_outcome_id: outcome.id, task_id: task.id)
        end

        link.rating = rating
        link.description = description

        link.save!

        if link.new_record?
          success << { row:row, message: "Link between task #{task_def.abbreviation} and outcome #{outcome.abbreviation} created for unit" }
        else
          success << { row:row, message: "Link between task #{task_def.abbreviation} and outcome #{outcome.abbreviation} updated for unit" }
        end

      rescue Exception => e
        errors << { row: row, message: "#{e.message}" }
      end
    end

    {
      success: success,
      ignored: ignored,
      errors:  errors
    }
  end

  def missing_headers(row, headers)
    headers - row.to_hash().keys
  end

  def import_groups_from_csv(group_set, file)
    success = []
    errors = []
    ignored = []

    logger.info "Starting import of group for #{group_set.name} for #{self.code}"

    CSV.parse(file, {
        :headers => true,
        :header_converters => [lambda { |i| i.nil? ? '' : i },  :downcase, lambda { |hdr| hdr.strip unless hdr.nil?}],
        :converters => [lambda{ |body| body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]
    }).each do |row|
      next if row[0] =~ /^(group_name)|(name)/ # Skip header

      begin
        missing = missing_headers(row, ['group_name', 'username', 'tutorial'])
        if missing.count > 0
          errors << { row: row, message: "Missing headers: #{missing.join(', ')}" }
          next
        end

        username = row['username'].downcase.strip unless row['username'].nil?
        group_name = row['group_name'].strip unless row['group_name'].nil?
        tutorial = row['tutorial'].strip unless row['tutorial'].nil?

        user = User.where(username: username).first

        if user.nil?
          errors << { row: row, message: "Unable to find user #{username}" }
          next
        end

        project = students.where('user_id = :id', id: user.id).first

        if project.nil?
          errors << { row: row,  message: "Student #{username} not found in unit" }
          next
        end

        grp = group_set.groups.find_or_create_by(name: group_name)

        change = ""

        if grp.new_record?
          tutorial = tutorial_with_abbr(tutorial)
          if tutorial.nil?
            errors << { row: row, message: "Tutorial #{tutorial} not found" }
            next
          end

          change = "Created new group. "
          grp.tutorial = tutorial
          grp.save!
        end

        begin
          grp.add_member(project)
        rescue Exception => e
          errors << { row: row, message: e.message }
          next
        end
        success << { row: row, message: "#{change}Added #{username} to #{grp.name}." }
      rescue Exception => e
        errors << { row: row, message: e.message}
      end
    end

    {
      success: success,
      ignored: ignored,
      errors:  errors
    }
  end

  def export_groups_to_csv(group_set)
    CSV.generate do |row|
      row << ["group_name", "username", "tutorial"]
      group_set.groups.each do |grp|
        grp.projects.each do |project|
          row << [grp.name, project.student.username,  grp.tutorial.abbreviation]
        end
      end
    end
  end

  # def import_tutorials_from_csv(file)
  #   CSV.foreach(file) do |row|
  #     next if row[0] =~ /Subject Code/ # Skip header

  #     class_type, abbrev, day, time, location, tutor_username = row[2..-1]
  #     next if class_type !~ /Lab/

  #     add_tutorial(day, time, location, tutor_username, abbrev)
  #   end
  # end

  def add_tutorial(day, time, location, tutor, abbrev)
    tutor_role = unit_roles.where("user_id=:user_id", user_id: tutor.id).first
    if tutor_role.nil? || tutor_role.role == Role.student
      return nil
    end

    Tutorial.create!( { unit_id: id, abbreviation: abbrev } ) do |tutorial|
      tutorial.meeting_day      = day
      tutorial.meeting_time     = time
      tutorial.meeting_location = location
      tutorial.unit_role_id     = tutor_role.id
    end
  end

  def date_for_week_and_day(week, day)
    return nil if week.nil? || day.nil?
    day_num = Date::ABBR_DAYNAMES.index day.titlecase
    return nil if day_num.nil?
    start_day_num = start_date.wday

    start_date + week.weeks + (day_num - start_day_num).days
  end

  def import_tasks_from_csv(file)
    success = []
    errors = []
    ignored = []

    CSV.parse(file, {
        :headers => true,
        :header_converters => [lambda { |i| i.nil? ? '' : i }, :downcase, lambda { |hdr| hdr.strip.gsub(" ", "_").to_sym unless hdr.nil? }],
        :converters => [lambda{ |body| body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]
    }).each do |row|
      next if row[0] =~ /^(Task Name)|(name)/ # Skip header

      begin
        missing = missing_headers(row, TaskDefinition.csv_columns)
        if missing.count > 0
          errors << { row: row, message: "Missing headers: #{missing.join(', ')}" }
          next
        end

        task_definition, new_task, message = TaskDefinition.task_def_for_csv_row(self, row)

        if task_definition.nil?
          errors << { row: row, message: message }
          next
        end

        success << { row: row, message: message }
      rescue Exception => e
        errors << { row: row, message: e.message }
      end
    end

    {
      success: success,
      ignored: ignored,
      errors:  errors
    }
  end

  def task_definitions_csv
    TaskDefinition.to_csv(task_definitions)
  end

  def task_completion_csv(options={})
    CSV.generate(options) do |csv|
      csv << [
        'Student ID',
        'Student Name',
        'Target Grade',
        'Email',
        'Portfolio',
        'Tutorial',
      ] + task_definitions.map{ |task_definition|
        if task_definition.is_graded
          [ task_definition.abbreviation, "#{task_definition.abbreviation} grade" ]
        else
          task_definition.abbreviation
        end
      }.flatten
      active_projects.each do |project|
        csv << project.task_completion_csv
      end
    end
  end

  #
  # Create a temp zip file with all student portfolios
  #
  def get_portfolio_zip(current_user)
    # Get a temp file path
    filename = FileHelper.sanitized_filename("portfolios-#{self.code}-#{current_user.username}.zip")
    result = Tempfile.new(filename)
    # Create a new zip
    Zip::File.open(result.path, Zip::File::CREATE) do | zip |
      active_projects.each do | project |
        # Skip if no portfolio at this time...
        next if not project.portfolio_available

        # Add file to zip in grade folder
        src_path = project.portfolio_path
        if project.main_tutor
          dst_path = FileHelper.sanitized_path( "#{project.target_grade_desc}", "#{project.student.username}-portfolio (#{project.main_tutor.name})") + ".pdf"
        else
          dst_path = FileHelper.sanitized_path( "#{project.target_grade_desc}", "#{project.student.username}-portfolio (no tutor)") + ".pdf"
        end

        #copy into zip
        zip.add(dst_path, src_path)
      end #active_projects
    end #zip
    result
  end

  #
  # Create a temp zip file with all student portfolios
  #
  def get_task_resources_zip()
    # Get a temp file path
    filename = FileHelper.sanitized_filename("task-resources-#{self.code}.zip")
    result = Tempfile.new(filename)
    # Create a new zip
    Zip::File.open(result.path, Zip::File::CREATE) do | zip |
      task_definitions.each do |td|
        if td.has_task_pdf?
          dst_path = FileHelper.sanitized_path( "#{td.abbreviation}") + ".pdf"
          zip.add(dst_path, td.task_sheet)
        end

        if td.has_task_resources?
          dst_path = FileHelper.sanitized_path( "#{td.abbreviation}") + ".zip"
          zip.add(dst_path, td.task_resources)
        end
      end
    end #zip
    result
  end

  #
  # Create an ILO
  #
  def add_ilo(name, desc, abbr)
    next_num = learning_outcomes.count + 1

    LearningOutcome.create!(
      unit_id: self.id,
      name: name,
      description: desc,
      abbreviation: abbr,
      ilo_number: next_num
    )
  end

  #
  # Reorder ILO sequence numbers based on ILO update
  #
  def move_ilo(ilo, new_num)
    if (ilo.ilo_number < new_num)
      logger.debug "Moving ILOs up #{ilo.ilo_number} to #{new_num}"
      learning_outcomes.where("ilo_number > #{ilo.ilo_number} and ilo_number <= #{new_num}").each { |ilo| ilo.ilo_number -= 1; ilo.save}
    elsif (ilo.ilo_number > new_num)
      learning_outcomes.where("ilo_number < #{ilo.ilo_number} and ilo_number >= #{new_num}").each { |ilo| ilo.ilo_number += 1; ilo.save}
    end
    ilo.ilo_number = new_num
    ilo.save
  end

  #
  # Get all of the related tasks
  #
  def tasks_for_definition(task_def)
    tasks.where(task_definition_id: task_def.id)
  end

  #
  # Update the student's max_pct_similar for all of their tasks
  #
  def update_student_max_pct_similar()
    projects.each do | p |
      p.max_pct_similar = p.tasks.maximum(:max_pct_similar)
      p.save
    end
  end

  def create_plagiarism_link(t1, t2, match)
    plk1 = PlagiarismMatchLink.where(task_id: t1.id, other_task_id: t2.id).first
    plk2 = PlagiarismMatchLink.where(task_id: t2.id, other_task_id: t1.id).first

    # Delete old links between tasks
    plk1.destroy unless plk1.nil? ## will delete its pair
    plk2.destroy unless plk2.nil?

    plk1 = PlagiarismMatchLink.create do | pml |
      pml.task = t1
      pml.other_task = t2
      pml.plagiarism_report_url = match[0][:url]

      pml.pct = match[0][:pct]
    end

    plk2 = PlagiarismMatchLink.create do | pml |
      pml.task = t2
      pml.other_task = t1
      pml.plagiarism_report_url = match[1][:url]

      pml.pct = match[1][:pct]
    end

    FileHelper.save_plagiarism_html(plk1, match[0][:html])
    FileHelper.save_plagiarism_html(plk2, match[1][:html])
  end

  def update_plagiarism_stats()
    moss = MossRuby.new(Doubtfire::Application.config.moss_key)

    task_definitions.where(plagiarism_updated: true).each do |td|
      td.plagiarism_updated = false
      td.save

      td.clear_related_plagiarism

      # Get results
      url = td.plagiarism_report_url
      logger.debug "Processing MOSS results #{url}"

      warn_pct = td.plagiarism_warn_pct
      warn_pct = 50 if warn_pct.nil?

      results = moss.extract_results( url, warn_pct, lambda { |line| puts line } )

      # Use results
      results.each do |match|
        next if match[0][:pct] < warn_pct && match[1][:pct] < warn_pct

        task_id_1 = /.*\/(\d+)\/$/.match(match[0][:filename])[1]
        task_id_2 = /.*\/(\d+)\/$/.match(match[1][:filename])[1]

        t1 = Task.find(task_id_1)
        t2 = Task.find(task_id_2)

        if t1.nil? || t2.nil?
          logger.error "Could not find tasks #{task_id_1} or #{task_id_2} for plagiarism stats check!"
          next
        end

        if td.group_set # its a group task
          g1_tasks = t1.group_submission.tasks
          g2_tasks = t2.group_submission.tasks

          g1_tasks.each do | gt1 |
            g2_tasks.each do | gt2 |
              create_plagiarism_link(gt1, gt2, match)
            end
          end

        else # just link the individuals...
          create_plagiarism_link(t1, t2, match)
        end
      end # end of each result
    end # for each task definition where it needs to be updated
    update_student_max_pct_similar()

    self
  end

  #
  # Extract all done files related to a task definition matching a pattern into a given directory.
  # Returns an array of files
  #
  def add_done_files_for_plagiarism_check_of(td, tmp_path, force, to_check)
    tasks = tasks_for_definition(td)
    tasks_with_files = tasks.select { |t| t.has_pdf }

    if td.group_set
      # group task so only select one member of each group
      seen_groups = []

      tasks_with_files = tasks_with_files.select do |t|
        if t.group.nil?
          result = false
        else
          result = ! seen_groups.include?(t.group)
          if result
            seen_groups << t.group
          end
        end
        result
      end
    end

    # check number of files, and they are new
    if tasks_with_files.count > 1 && (tasks.where("tasks.file_uploaded_at > ?", last_plagarism_scan ).select { |t| t.has_pdf }.count > 0 || force )
      td.plagiarism_checks.each do |check|
        next if check["type"].nil?

        type_data = check["type"].split(" ")
        next if type_data.nil? or type_data.length != 2 or type_data[0] != "moss"

        # extract files matching each pattern
        # -- each pattern
        check["pattern"].split("|").each do |pattern|
          tasks_with_files.each do |t|
            FileHelper.extract_file_from_done(t, tmp_path, pattern, lambda { | task, to_path, name |  File.join("#{to_path}", "#{t.student.username}", "#{name}") } )
          end
          MossRuby.add_file(to_check, "**/#{pattern}")
        end
      end
    end

    self
  end

  #
  # Pass tasks on to plagarism detection software and setup links between students
  #
  def check_plagiarism(force = false)
    # Get each task...
    return if not active

    # need pwd to restore after cding into submission folder (so the files do not have full path)
    pwd = FileUtils.pwd

    begin
      logger.info "Checking plagiarsm for unit #{code} - #{name} (id=#{id})"
      task_definitions.each do |td|
        next if td.plagiarism_checks.length == 0
        # Is there anything to check?

        logger.debug "Checking plagiarism for #{td.name} (id=#{td.id})"
        tasks = tasks_for_definition(td)
        tasks_with_files = tasks.select { |t| t.has_pdf }
        if tasks_with_files.count > 1 && (tasks.where("tasks.file_uploaded_at > ?", last_plagarism_scan ).select { |t| t.has_pdf }.count > 0 || td.updated_at > last_plagarism_scan || force )
          # There are new tasks, check these

          logger.debug "Contacting MOSS for new checks"
          td.plagiarism_checks.each do |check|
            next if check["type"].nil?

            type_data = check["type"].split(" ")
            next if type_data.nil? or type_data.length != 2 or type_data[0] != "moss"

            # Create the MossRuby object
            moss = MossRuby.new(Doubtfire::Application.config.moss_key)

            # Set options  -- the options will already have these default values
            moss.options[:max_matches] = 7
            moss.options[:directory_submission] = true
            moss.options[:show_num_matches] = 500
            moss.options[:experimental_server] = false
            moss.options[:comment] = ""
            moss.options[:language] = type_data[1]

            tmp_path = File.join( Dir.tmpdir, 'doubtfire', "check-#{id}-#{td.id}" )

            begin
              # Create a file hash, with the files to be processed
              to_check = MossRuby.empty_file_hash
              add_done_files_for_plagiarism_check_of(td, tmp_path, force, to_check)

              FileUtils.chdir(tmp_path)

              # Get server to process files
              logger.debug "Sending to MOSS..."
              url = moss.check(to_check, lambda { |line| puts line })

              logger.info "MOSS check for #{code} #{td.abbreviation} url: #{url}"

              td.plagiarism_report_url = url
              td.plagiarism_updated = true
              td.save
            rescue => e
              logger.error "Failed to check plagiarism for task #{td.name} (id=#{td.id}). Error: #{e.message}"
            ensure
              FileUtils.chdir(pwd)
              FileUtils.rm_rf tmp_path
            end
          end
        end
      end
      update_student_max_pct_similar()
      self.last_plagarism_scan = DateTime.now
      self.save!
    ensure
      if FileUtils.pwd() != pwd
        FileUtils.chdir(pwd)
      end
    end

    self
  end

  def import_task_files_from_zip zip_file
    task_path = FileHelper.task_file_dir_for_unit self, create=true

    result = {
      :added_files => [],
      :ignored_files => []
    }

    Zip::File.open(zip_file) do |zip|
      zip.each do |file|
        file_name = File.basename(file.name)
        if not task_definitions.where(abbreviation: File.basename(file_name, ".*"))
          result[:ignored_files] << { name: file.name }
        elsif File.extname(file.name) == ".pdf"
          file.extract ("#{task_path}#{FileHelper.sanitized_filename(file_name)}") {true}
          result[:added_files] << { name: file.name }
        elsif File.extname(file.name) == ".zip"
          file.extract ("#{task_path}#{FileHelper.sanitized_filename(file_name)}") {true}
          result[:added_files] << { name: file.name }
        else
          result[:ignored_files] << { name: file.name }
        end
      end
    end

    result
  end

  def path_to_task_resources(task_def)
    task_path = FileHelper.task_file_dir_for_unit self, create=true
    "#{task_path}#{FileHelper.sanitized_filename(task_def.abbreviation)}.zip"
  end

  def path_to_task_pdf(task_def)
    task_path = FileHelper.task_file_dir_for_unit self, create=true
    "#{task_path}#{FileHelper.sanitized_filename(task_def.abbreviation)}.pdf"
  end

  #
  # Return the tasks that are waiting for feedback
  #
  def tasks_awaiting_feedback
    student_tasks.
      joins(:task_status).
      select("project_id", "tasks.id as id", "task_definition_id", "projects.tutorial_id as tutorial_id", "task_statuses.name as status_name", "completion_date", "times_assessed", "submission_date", "portfolio_evidence").
      where('task_statuses.id IN (:ids)', ids: [ TaskStatus.ready_to_mark, TaskStatus.need_help, TaskStatus.discuss, TaskStatus.demonstrate ]).
      where('(task_definitions.due_date IS NULL OR task_definitions.due_date > tasks.submission_date)').
      order('task_definition_id') #.
      # map { |t|
      #   {
      #     project_id: t.project_id,
      #     id: t.id,
      #     task_definition_id: t.task_definition_id,
      #     tutorial_id: t.tutorial_id,
      #     status: TaskStatus.status_key_for_name(t.status_name),
      #     completion_date: t.completion_date,
      #     submission_date: t.submission_date,
      #     times_assessed: t.times_assessed
      #     # has_pdf: t.has_pdf
      #   }
      # }
  end


  #
  # Return stats on the number of students in each status for each task / tutorial
  #
  # Returns a map:
  #   task_def_id => {
  #     tutorial_id => [ { :status=> :not_started, :num=>1}, ... ],
  #     tutorial_id => [ { :status=> :not_started, :num=>1}, ... ], ...
  #   },
  #   task_def_id => { ... }
  #
  def task_status_stats
    data = student_tasks.
      joins(:task_status).
      select('projects.tutorial_id as tutorial_id', 'task_definition_id', 'task_statuses.name as status_name', 'COUNT(tasks.id) as num_tasks').
      where('task_status_id > 1').
      group('projects.tutorial_id', 'tasks.task_definition_id', 'task_statuses.name').
      map { |r|
        {
          tutorial_id: r.tutorial_id,
          task_definition_id: r.task_definition_id,
          status: TaskStatus.status_key_for_name(r.status_name),
          num: r.num_tasks
        }
      }

    # Calculate not started...
    tutorials.each do |t|
      task_definitions.each do |td|
        count = data.select{|r| r[:task_definition_id] == td.id && r[:tutorial_id] == t.id }.map{|r| r[:num]}.inject(:+)
        count = 0 unless count

        num = t.projects.where("projects.enrolled = TRUE AND projects.target_grade >= :grade", grade: td.target_grade).count
        num = 0 unless num

        if num - count > 0
          data << {
            tutorial_id: t.id,
            task_definition_id: td.id,
            status: :not_started,
            num: num - count
          }
        end
      end
    end

    result = {}

    task_definitions.each do |td|
      result[td.id] = {}
    end

    data.each do |e|
      if not result[e[:task_definition_id]].has_key? e[:tutorial_id]
        result[e[:task_definition_id] ] [e[:tutorial_id]] = []
      end

      result[e[:task_definition_id]][e[:tutorial_id]] << { status: e[:status], num: e[:num] }
    end

    result
  end

  #
  # Returns an array of { tutorial_id: id, grade: g, num: n } -- showing the number of students
  # aiming for a grade in this indicated unit.
  #
  def student_target_grade_stats
    data = active_projects.select('projects.tutorial_id, projects.target_grade, COUNT(projects.id) as num'
      ).group('projects.tutorial_id, projects.target_grade'
      ).order('projects.tutorial_id, projects.target_grade'
      ).map { |r| {tutorial_id: r.tutorial_id, grade: r.target_grade, num: r.num} }
  end

  #
  # Returns the basic data used in calculating the student task completion stats
  #
  def _student_task_completion_data_base()
    data = student_tasks.
      select('projects.tutorial_id as tutorial_id', 'projects.target_grade as target_grade', "tasks.project_id", "Count(tasks.id) as num").
      where('task_status_id = :complete', complete: TaskStatus.complete.id).
      group('projects.tutorial_id','projects.target_grade','tasks.project_id').
      order('projects.tutorial_id')
    data.map { |r| { tutorial_id: r.tutorial_id, grade: r.target_grade, project: r.project_id, num: r.num} }
  end

  def _calculate_task_completion_stats(data)
    values = data.map { |r|  r[:num] }

    if values && values.length > 4
      values.sort!

      if values.length % 2 == 0
        median_value = ((values[values.length / 2] + values[values.length/2 - 1]) / 2.0).round(1)
      else
        median_value = values[values.length / 2]
      end

      lower_value = values[values.length * 3 / 10]
      upper_value = values[values.length * 8 / 10]

      {
        median: median_value,
        lower: lower_value,
        upper: upper_value,
        min: values.first,
        max: values.last
      }
    else
      {
        median: 0,
        lower: 0,
        upper: 0,
        min: 0,
        max: 0
      }
    end
  end

  #
  # Returns a map with min, max, lower, upper, and median task completion data.
  # i.e. how many tasks students have completed
  #
  def student_task_completion_stats()
    data = _student_task_completion_data_base()

    result = {}
    result[:unit] = _calculate_task_completion_stats(data)
    result[:tutorial] = {}
    result[:grade] = {}

    tutorials.each do |t|
      result[:tutorial][t.id] = _calculate_task_completion_stats(data.select{|r| r[:tutorial_id] == t.id})
    end

    for i in 0..3 do
      result[:grade][i] = _calculate_task_completion_stats(data.select{|r| r[:grade] == i})
    end

    result
  end

  #
  # Returns a result that maps tutorial_id -> { student outcome map }
  # Where the student outcome map contains each LO and its rating for that student (no student id)
  #
  def student_ilo_progress_stats
    data = student_tasks.
      joins(task_definition: :learning_outcome_task_links).
      joins(:task_status).
      select('projects.tutorial_id, projects.id as project_id, task_statuses.name as status_name, task_definitions.target_grade, learning_outcome_task_links.learning_outcome_id, learning_outcome_task_links.rating, COUNT(tasks.id) as num').
      where("projects.started = TRUE AND learning_outcome_task_links.task_id is NULL").
      group('projects.tutorial_id, projects.id, task_statuses.name, task_definitions.target_grade, learning_outcome_task_links.learning_outcome_id, learning_outcome_task_links.rating').
      order('projects.tutorial_id, projects.id').
      map { |r|
        {
          project_id: r.project_id,
          tutorial_id: r.tutorial_id,
          learning_outcome_id: r.learning_outcome_id,
          rating: r.rating,
          grade: r.target_grade,
          status: TaskStatus.status_key_for_name(r.status_name),
          num: r.num
        }
      }

    grade_weight = { 0 => 1, 1 => 2, 2 => 4, 3 => 8 }
    status_weight = {
      not_started:        0.0,
      fail:               0.0,
      working_on_it:      0.0,
      need_help:          0.0,
      redo:               0.1,
      do_not_resubmit:    0.1,
      fix_and_resubmit:   0.3,
      ready_to_mark:      0.5,
      discuss:            0.8,
      demonstrate:        0.8,
      complete:           1.0
    }

    result = {}

    # order by tutorial and project...
    current = nil
    data.each do |e|
      # chech for change in tutorial
      if current.nil? || e[:tutorial_id] != current[:tutorial_id]
        # if there was a currentious element
        if current
          # add the project to the tutorial
          current[:tutorial] << current[:project]

          # add the tutorial to the results
          result[current[:tutorial_id]] = current[:tutorial]
        end

        current = {project_id: e[:project_id], tutorial_id: e[:tutorial_id], tutorial: [], project: {id: e[:project_id]} }
      elsif e[:project_id] != current[:project_id] # check change of project
        # add the project to the tutorial
        current[:tutorial] << current[:project]

        # reset the
        current[:project_id] = e[:project_id]
        current[:project] = { id: e[:project_id] }
      end

      old_val = 0
      if current[:project].has_key? e[:learning_outcome_id]
        old_val = current[:project][e[:learning_outcome_id]]
      end

      current[:project][e[:learning_outcome_id]] = old_val +
        e[:rating] * status_weight[e[:status]] * grade_weight[e[:grade]] * e[:num]
    end

    # Add last project/tutorial to results
    if current
      # add the project to the tutorial
      current[:tutorial] << current[:project]

      # add the tutorial to the results
      result[current[:tutorial_id]] = current[:tutorial]
    end

    result.each do |tutorial_id_key, array_of_ilo_scores|
      result[tutorial_id_key] = array_of_ilo_scores.map do | map_scores |
        map_scores.each { |ilo_id, score| map_scores[ilo_id] = score.round(1) }
        map_scores
      end
    end

    result
  end

  # Functions processes the ilo data to generate stats
  # Can be passed all details, or details for one tutorial.
  def _ilo_progress_summary(data)
    result = {}

    learning_outcomes.each do |ilo|
      if data.nil?
        lower_value = upper_value = median_value = min_value = max_value = 0
      else
        values = data.map { |e| (e.has_key? ilo.id) ? e[ilo.id] : 0 }
        values = values.sort

        if values.length % 2 == 0
          median_value = ((values[values.length / 2] + values[values.length/2 - 1]) / 2.0).round(1)
        else
          median_value = values[values.length / 2]
        end

        lower_value = values[values.length * 3 / 10]
        upper_value = values[values.length * 8 / 10]
        min_value = values.first
        max_value = values.last
      end

      result[ilo.id] = {
          median: median_value,
          lower: lower_value,
          upper: upper_value,
          min: min_value,
          max: max_value
        }
    end

    result
  end

  #
  # Returns the details of the ILO progress for students in the class.
  #
  def ilo_progress_class_details
    result = {}
    return result if students.length < 10

    data = student_ilo_progress_stats

    return {} if data.nil?

    tutorials.each do |tute|
      result[tute.id] = _ilo_progress_summary(data[tute.id])
      # if data[tute.id]
      #   result[tute.id][:students] = data[tute.id]
      # else
      #   result[tute.id][:students] = []
      # end
    end

    result['all'] = _ilo_progress_summary(data.values.reduce(:+))

    result
  end

  def ilo_progress_class_stats
    return {} if students.length < 10

    temp = student_ilo_progress_stats.values

    return {} if temp.nil?

    data = temp.reduce(:+)

    _ilo_progress_summary(data)
  end

  def student_grades_csv
    students_with_grades = students.where("grade > 0")

    CSV.generate do |row|
      row << ["unit_code", "username", "grade", "rationale"]
      students_with_grades.each do |project|
        row << [project.unit.code, project.student.username,  project.grade, project.grade_rationale]
      end
    end
  end
end
