require 'csv'
require 'bcrypt'
require 'json'
require 'moss_ruby'
require 'csv_helper'

class Unit < ActiveRecord::Base
  include ApplicationHelper
  include FileHelper
  include LogHelper
  include MimeCheckHelpers
  include CsvHelper

  validates :description, length: { maximum: 4095, allow_blank: true }
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
      student: student_role_permissions,
      tutor: tutor_role_permissions,
      convenor: convenor_role_permissions,
      nil: nil_role_permissions
    }
  end

  def role_for(user)
    if convenors.where('unit_roles.user_id=:id', id: user.id).count == 1
      Role.convenor
    elsif tutors.where('unit_roles.user_id=:id', id: user.id).count == 1
      Role.tutor
    elsif active_projects.where('projects.user_id=:id', id: user.id).count == 1
      Role.student
    end
  end

  validates :name, :description, :start_date, :end_date, presence: true

  # Model associations.
  # When a Unit is destroyed, any TaskDefinitions, Tutorials, and ProjectConvenor instances will also be destroyed.
  has_many :task_definitions, -> { order 'start_date ASC, abbreviation ASC' }, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :tutorials, dependent: :destroy
  has_many :unit_roles, dependent: :destroy
  has_many :learning_outcomes, dependent: :destroy
  has_many :tasks, through: :projects
  has_many :group_sets, dependent: :destroy
  has_many :task_engagements, through: :projects
  has_many :comments, through: :projects
  has_many :groups, through: :group_sets

  has_many :learning_outcome_task_links, through: :task_definitions

  has_many :convenors, -> { joins(:role).where('roles.name = :role', role: 'Convenor') }, class_name: 'UnitRole'
  has_many :staff, ->     { joins(:role).where('roles.name = :role_convenor or roles.name = :role_tutor', role_convenor: 'Convenor', role_tutor: 'Tutor') }, class_name: 'UnitRole'

  scope :current,               -> { current_for_date(Time.zone.now) }
  scope :current_for_date,      ->(date) { where('start_date <= ? AND end_date >= ?', date, date) }
  scope :not_current,           -> { not_current_for_date(Time.zone.now) }
  scope :not_current_for_date,  ->(date) { where('start_date > ? OR end_date < ?', date, date) }
  scope :set_active,            -> { where('active = ?', true) }
  scope :set_inactive,          -> { where('active = ?', false) }

  def ordered_ilos
    learning_outcomes.order(:ilo_number)
  end

  def task_outcome_alignments
    learning_outcome_task_links.where('task_id is NULL')
  end

  def student_tasks
    tasks.joins(:task_definition).where('projects.enrolled = TRUE AND projects.target_grade >= task_definitions.target_grade')
  end

  def self.for_user_admin(user)
    if user.has_admin_capability?
      Unit.all
    else
      Unit.joins(:unit_roles).where('unit_roles.user_id = :user_id and unit_roles.role_id = :convenor_role', user_id: user.id, convenor_role: Role.convenor.id)
    end
  end

  def self.default
    unit = new

    unit.name         = 'New Unit'
    unit.description  = 'Enter a description for this unit.'
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

  def main_convenor
    convenors.first.user
  end

  def students
    projects
  end

  def student_query(limit_to_enrolled)
    # Get the number of tasks for each grade... with 1 as minimum to avoid / 0
    task_count = [0, 1, 2, 3].map do |e|
      task_definitions.where("target_grade <= #{e}").count + 0.0
    end.map { |e| e == 0 ? 1 : e }

    q = projects
        .joins(:user)
        .joins('LEFT OUTER JOIN tasks ON projects.id = tasks.project_id')
        .joins('LEFT JOIN task_definitions ON tasks.task_definition_id = task_definitions.id')
        .joins('LEFT OUTER JOIN plagiarism_match_links ON tasks.id = plagiarism_match_links.task_id')
        .group(
          'projects.id',
          'projects.target_grade',
          'projects.enrolled',
          'users.first_name',
          'users.last_name',
          'users.username',
          'users.email',
          'projects.tutorial_id',
          'projects.portfolio_production_date',
          'projects.compile_portfolio',
          'projects.grade',
          'projects.grade_rationale'
        )
        .select(
          'projects.id AS project_id',
          'projects.enrolled AS enrolled',
          'users.first_name AS first_name',
          'users.last_name AS last_name',
          'users.username AS student_id',
          'users.email AS student_email',
          'projects.target_grade AS target_grade',
          'projects.tutorial_id AS tutorial_id',
          'projects.compile_portfolio AS compile_portfolio',
          'projects.grade AS grade',
          'projects.grade_rationale AS grade_rationale',
          'projects.portfolio_production_date AS portfolio_production_date',
          'MAX(CASE WHEN plagiarism_match_links.dismissed = FALSE THEN plagiarism_match_links.pct ELSE 0 END) AS plagiarism_match_links_max_pct',
          *TaskStatus.all.map { |s| "SUM(CASE WHEN tasks.task_status_id = #{s.id} THEN 1 ELSE 0 END) AS #{s.status_key}_count" }
        )
        .where(
          'projects.target_grade >= task_definitions.target_grade OR (task_definitions.target_grade IS NULL)'
        )
        .order('users.first_name')

    q = q.where('projects.enrolled = TRUE') if limit_to_enrolled

    q.map do |t|
      {
        project_id: t.project_id,
        enrolled: t.enrolled,
        first_name: t.first_name,
        last_name: t.last_name,
        student_id: t.student_id,
        student_email: t.student_email,
        student_name: "#{t.first_name} #{t.last_name}",
        target_grade: t.target_grade,
        tutorial_id: t.tutorial_id,
        compile_portfolio: t.compile_portfolio,
        grade: t.grade,
        grade_rationale: t.grade_rationale,
        max_pct_copy: t.plagiarism_match_links_max_pct,
        has_portfolio: !t.portfolio_production_date.nil?,
        stats: Project.create_task_stats_from(task_count, t, t.target_grade)
      }
    end
  end

  #
  # Last date/time of scan
  #
  def last_plagarism_scan
    if self[:last_plagarism_scan].nil?
      DateTime.new(2000, 1, 1)
    else
      self[:last_plagarism_scan]
    end
  end

  #
  # Returns the email of the first convenor or the first administrator if there
  # are no convenors
  #
  def convenor_email
    convenor = convenors.first
    if convenor
      convenor.user.email
    else
      User.admins.first.email
    end
  end

  def active_projects
    projects.where('enrolled = true')
  end

  # Adds a staff member for a role in a unit
  def employ_staff(user, role)
    old_role = unit_roles.where('user_id=:user_id', user_id: user.id).first
    return old_role unless old_role.nil?

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
  def enrol_student(user, tutorial = nil)
    tutorial_id = if tutorial.is_a?(Tutorial)
                    tutorial.id
                  else
                    tutorial
                  end

    # Validates that a student is not already assigned to the unit
    existing_project = projects.where('user_id=:user_id', user_id: user.id).first
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
    if !tutorial_id.nil? && tutorials.where('id=:id', id: tutorial_id).count == 0
      return nil
    end

    project = Project.create!(
      user_id: user.id,
      unit_id: id,
      task_stats: '0.0|1.0|0.0|0.0|0.0'
    )

    project.tutorial_id = tutorial_id unless tutorial_id.nil?
    project.save
    project
  end

  def tutorial_with_abbr(abbr)
    tutorials.where(abbreviation: abbr).first
  end

  #
  # Imports users into a project from CSV file.
  # Format: Unit Code, Student ID,First Name, Surname, email, tutorial
  # Expected columns: unit_code, username, first_name, last_name, email, tutorial
  #
  def import_users_from_csv(file)
    tutorial_cache = {}
    success = []
    errors = []
    ignored = []

    csv = CSV.new(File.read(file), headers: true,
        header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
        converters: [->(i) { i.nil? ? '' : i }, ->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]
        )

    # Read the header row to determine what kind of file it is
    if csv.header_row?
      csv.shift
    else
      errors << {row: [], message: "Header row missing" }
      return
    end

    # Check if these headers should be processed by institution file or from DF format
    if Doubtfire::Application.config.institution_settings.are_headers_institution_users? csv.headers
      import_settings = Doubtfire::Application.config.institution_settings.user_import_settings_for(csv.headers)
    else
      # Settings include:
      #   missing_headers_lambda - lambda to check if row is missing key data
      #   fetch_row_data_lambda - lambda to convert row from csv to required import data
      #   replace_existing_tutorial - boolean to indicate if tutorials in csv override ones in doubtfire
      import_settings = {
        missing_headers_lambda: ->(row) {
          missing_headers(row, %w(unit_code username student_id first_name last_name email tutorial))
        },
        fetch_row_data_lambda: ->(row, unit) {
          {
              unit_code:      row['unit_code'],
              username:       row['username'],
              student_id:     row['student_id'],
              first_name:     row['first_name'],
              nickname:       nil,
              last_name:      row['last_name'],
              email:          row['email'],
              enrolled:       true,
              tutorial_code:  row['tutorial']
          }
        },
        replace_existing_tutorial: true
      }
    end

    # Record changes ready to process - map on username to ensure only one option per user
    # enrol will override withdraw
    changes = {}

    # Determine kind of file to process
    CSV.foreach(file, headers: true,
                      header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                      converters: [->(i) { i.nil? ? '' : i }, ->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]) do |row|
      
      missing = import_settings[:missing_headers_lambda].call(row)
      if missing.count > 0
        errors << { row: row, message: "Missing headers: #{missing.join(', ')}" }
        next
      end

      begin
        row_data = import_settings[:fetch_row_data_lambda].call(row, self)

        row_data[:row] = row

        if row_data[:username].nil?
          ignored << { row: row, message: "Skipping row with missing username" }
          next
        end

        unit_code = row_data[:unit_code]

        if unit_code != code
          ignored << { row: row, message: "Invalid unit code. #{unit_code} does not match #{code}" }
          next
        end

        # now record changes...
        username = row_data[:username].downcase

        # do we already have this user?
        if changes.key? username
          if row_data[:enrolled] # they should be enrolled - record that... overriding anything else
            # record previous row as ignored
            ignored << { row: changes[username][:row], message: "Skipping withdraw as also includes enrol" }
            changes[username] = row_data
          else
            # record this row as skipped
            ignored << { row: row, message: "Skipping withdraw as also includes enrol" }
          end
        else #dont have the user so record them - will add to result when processed
          changes[username] = row_data
        end
      rescue Exception => e
        errors << { row: row, message: e.message }
      end 
    end # for each csv row

    # now apply the changes...
    changes.each do |key, row_data|
      begin
        row = row_data[:row]
        username = row_data[:username].downcase
        unit_code = row_data[:unit_code]
        student_id = row_data[:student_id]
        first_name = row_data[:first_name].nil? ? nil : row_data[:first_name].titleize
        last_name = row_data[:last_name].nil? ? nil : row_data[:last_name].titleize
        nickname = row_data[:nickname].nil? ? nil : row_data[:nickname].titleize
        email = row_data[:email]
        tutorial_code = row_data[:tutorial_code]

        # If either first or last name is nil... copy over the other component
        first_name = first_name || last_name
        last_name = last_name || first_name
        nickname = nickname || first_name

        if !email =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
          errors << { row: row, message: "Invalid email address (#{email})" }
          next
        end

        # Perform withdraw if needed...
        unless row_data[:enrolled]
          # Find the user
          project_participant = User.where(username: username)
          
          # If they dont exist... ignore
          if project_participant.nil? || project_participant.count == 0
            ignored << { row: row, message: "Ignoring student to withdraw, as not enrolled" }
          else
            # Get the user's project
            user_project = projects.where(user_id: project_participant.first.id).first

            # If no project... then not enrolled
            if user_project.nil? || !user_project.enrolled
              ignored << { row: row, message: "Ignoring student to withdraw, as not enrolled" }
            else
              # Withdraw...
              user_project.enrolled = false 
              user_project.save
              success << { row: row, message: "Student was withdrawn" }
            end
          end

          # Move to next row as this was a withdraw...
          next
        end

        # Is an enrolment... so first find the user
        project_participant = User.find_or_create_by(username: username) do |new_user|
          new_user.first_name         = first_name
          new_user.last_name          = last_name
          new_user.student_id         = student_id
          new_user.nickname           = nickname
          new_user.role_id            = Role.student_id
          new_user.email              = email
          new_user.encrypted_password = BCrypt::Password.create('password')
        end

        # If new user then make sure they are saved
        unless project_participant.persisted?
          project_participant.save
        end

        #
        # Only import if a valid user - or if save worked
        #
        if project_participant.persisted?
          # Add in the student id if it was supplied...
          if (project_participant.student_id.nil? || project_participant.student_id.empty?) && student_id
            project_participant.student_id = student_id
            project_participant.save!
          end

          # Now find the project for the user
          user_project = projects.where(user_id: project_participant.id).first

          # And find the tutorial for the user
          tutorial = tutorial_cache[tutorial_code] || tutorial_with_abbr(tutorial_code)
          tutorial_cache[tutorial_code] ||= tutorial

          # Add the user to the project (if not already in there)
          if user_project.nil?
            # Need to enrol user... can always set tutorial as does not already exist...
            if (!tutorial.nil?) 
              # Use tutorial if we have it :)
              enrol_student(project_participant, tutorial)
              success << { row: row, message: 'Enrolled student with tutorial.' }
            else
              enrol_student(project_participant)
              success << { row: row, message: 'Enrolled student without tutorial.' }
            end
          else
            # update enrolment... if currently not enrolled
            changes = ''
            unless user_project.enrolled
              user_project.enrolled = true
              user_project.save
              changes << 'Changed enrolment.'
            end

            # replace tutorial if we are allowed... and it has changed
            if import_settings[:replace_existing_tutorial] || user_project.tutorial.nil?
              # check it has changed first...
              if user_project.tutorial != tutorial
                user_project.tutorial = tutorial
                user_project.save
                changes << 'Changed tutorial. '
              end
            end

            # Get back to user with changes... if any
            if changes.empty?
              ignored << { row: row, message: 'No change.' }
            else
              success << { row: row, message: changes }
            end
          end
        else
          errors << { row: row, message: "Student record is invalid. #{project_participant.errors.full_messages.first}" }
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

    CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
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

        unless project_participant
          errors << { row: row, message: "User #{username} not found" }
          next
        end
        unless project_participant.count == 1
          errors << { row: row, message: "User #{username} not found" }
          next
        end

        project_participant = project_participant.first

        user_project = projects.where(user_id: project_participant.id).first

        unless user_project
          ignored << { row: row, message: "User #{username} not enrolled in unit" }
          next
        end

        if user_project.enrolled
          user_project.enrolled = false
          user_project.save
          success << { row: row, message: "User #{username} withdrawn from unit" }
        else
          ignored << { row: row, message: "User #{username} not enrolled in unit" }
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
      row << %w(unit_code username student_id first_name last_name email tutorial)
      active_projects.each do |project|
        row << [project.unit.code, project.student.username, project.student.student_id, project.student.first_name, project.student.last_name, project.student.email, project.tutorial_abbr]
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

    CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/

      begin
        LearningOutcome.create_from_csv(self, row, result)
      rescue Exception => e
        result[:errors] << { row: row, message: e.message.to_s }
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

    CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/

      begin
        unit_code = row['unit_code']

        if unit_code != code
          ignored << { row: row, message: "Invalid unit code. #{unit_code} does not match #{code}" }
          next
        end

        outcome_abbr = row['learning_outcome']
        outcome = learning_outcomes.where('abbreviation = :abbr', abbr: outcome_abbr).first

        if outcome.nil?
          errors << { row: row, message: "Unable to locate learning outcome with abbreviation #{outcome_abbr}" }
          next
        end

        task_def_abbr = row['task_abbr']
        task_def = task_definitions.where('abbreviation = :abbr', abbr: task_def_abbr).first

        if task_def.nil?
          errors << { row: row, message: "Unable to locate task with abbreviation #{task_def_abbr}" }
          next
        end

        rating = row['rating'].to_i
        description = row['description']

        if for_project.nil?
          link = LearningOutcomeTaskLink.find_or_create_by(task_definition_id: task_def.id, learning_outcome_id: outcome.id, task_id: nil)
        else
          task = for_project.tasks.where('task_definition_id = :tdid', tdid: task_def.id).first

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
          success << { row: row, message: "Link between task #{task_def.abbreviation} and outcome #{outcome.abbreviation} created for unit" }
        else
          success << { row: row, message: "Link between task #{task_def.abbreviation} and outcome #{outcome.abbreviation} updated for unit" }
        end

      rescue Exception => e
        errors << { row: row, message: e.message.to_s }
      end
    end

    {
      success: success,
      ignored: ignored,
      errors:  errors
    }
  end

  def import_groups_from_csv(group_set, file)
    success = []
    errors = []
    ignored = []

    logger.info "Starting import of group for #{group_set.name} for #{code}"

    CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      next if row[0] =~ /^(group_name)|(name)/ # Skip header

      begin
        missing = missing_headers(row, %w(group_name group_number username tutorial))
        if missing.count > 0
          errors << { row: row, message: "Missing headers: #{missing.join(', ')}" }
          next
        end

        if row['username'].nil?
          ignored << { row: row, message: "Skipping row with missing username" }
          next
        end

        username = row['username'].downcase.strip unless row['username'].nil?
        group_name = row['group_name'].strip unless row['group_name'].nil?
        group_number = row['group_number'].strip unless row['group_number'].nil?
        tutorial = row['tutorial'].strip unless row['tutorial'].nil?

        user = User.where(username: username).first

        if user.nil?
          errors << { row: row, message: "Unable to find user #{username}" }
          next
        end

        project = students.where('user_id = :id', id: user.id).first

        if project.nil?
          errors << { row: row, message: "Student #{username} not found in unit" }
          next
        end

        grp = group_set.groups.find_or_create_by(name: group_name)

        change = ''

        if grp.new_record?
          tutorial = tutorial_with_abbr(tutorial)
          if tutorial.nil?
            errors << { row: row, message: "Tutorial #{tutorial} not found" }
            next
          end

          change = 'Created new group. '
          grp.tutorial = tutorial
          grp.number = group_number
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
        errors << { row: row, message: e.message }
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
      row << %w(group_name group_number username tutorial)
      group_set.groups.each do |grp|
        grp.projects.each do |project|
          row << [grp.name, grp.number, project.student.username, grp.tutorial.abbreviation]
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
    tutor_role = unit_roles.where('user_id=:user_id', user_id: tutor.id).first
    return nil if tutor_role.nil? || tutor_role.role == Role.student
    Tutorial.create!(unit_id: id, abbreviation: abbrev) do |tutorial|
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

    CSV.parse(file,
              headers: true,
              header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip.tr(' ', '_').to_sym unless hdr.nil? }],
              converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]
              ).each do |row|
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

  def task_definitions_by_grade
    # Need to search as relation is already ordered
    TaskDefinition.where(unit_id: id).order('target_grade ASC, start_date ASC, abbreviation ASC')
  end

  def task_completion_csv(options = {})
    CSV.generate(options) do |csv|
      csv << [
        'Student ID',
        'Student Name',
        'Target Grade',
        'Email',
        'Portfolio',
        'Tutorial',
        'Tutor'
      ] +
             group_sets.map(&:name) +
             task_definitions_by_grade.map do |task_definition|
               result = [ task_definition.abbreviation ]
               result << "#{task_definition.abbreviation} grade" if task_definition.is_graded?
               result << "#{task_definition.abbreviation} stars" if task_definition.has_stars?
               result << "#{task_definition.abbreviation} contribution" if task_definition.is_group_task?
               result
             end.flatten
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
    filename = FileHelper.sanitized_filename("portfolios-#{code}-#{current_user.username}.zip")
    result = Tempfile.new(filename)
    # Create a new zip
    Zip::File.open(result.path, Zip::File::CREATE) do |zip|
      active_projects.each do |project|
        # Skip if no portfolio at this time...
        next unless project.portfolio_available

        # Add file to zip in grade folder
        src_path = project.portfolio_path
        if project.main_tutor
          dst_path = FileHelper.sanitized_path(project.target_grade_desc.to_s, "#{project.student.username}-portfolio (#{project.main_tutor.name})") + '.pdf'
        else
          dst_path = FileHelper.sanitized_path(project.target_grade_desc.to_s, "#{project.student.username}-portfolio (no tutor)") + '.pdf'
        end

        # copy into zip
        zip.add(dst_path, src_path)
      end # active_projects
    end # zip
    result
  end

  #
  # Create a temp zip file with all student portfolios
  #
  def get_task_resources_zip
    # Get a temp file path
    filename = FileHelper.sanitized_filename("task-resources-#{code}.zip")
    result = Tempfile.new(filename)
    # Create a new zip
    Zip::File.open(result.path, Zip::File::CREATE) do |zip|
      task_definitions.each do |td|
        if td.has_task_sheet?
          dst_path = FileHelper.sanitized_filename(td.abbreviation.to_s) + '.pdf'
          zip.add(dst_path, td.task_sheet)
        end

        if td.has_task_resources?
          dst_path = FileHelper.sanitized_filename(td.abbreviation.to_s) + '.zip'
          zip.add(dst_path, td.task_resources)
        end
      end
    end # zip
    result
  end

  #
  # Create a temp zip file with all submission PDFs for a task
  #
  def get_task_submissions_pdf_zip(current_user, td)
    # Get a temp file path
    filename = FileHelper.sanitized_filename("submissions-#{code}-#{td.abbreviation}-#{current_user.username}-pdfs")
    result = Tempfile.new([filename, '.zip'])

    tasks_with_files = td.related_tasks_with_files

    # Create a new zip
    Zip::File.open(result.path, Zip::File::CREATE) do |zip|
      Dir.mktmpdir do |dir|
        # Extract all of the files...
        tasks_with_files.each do |task|
          path_part = if td.is_group_task? && task.group
                        task.group.name.to_s
                      else
                        task.student.username.to_s
                      end

          FileUtils.cp task.portfolio_evidence, File.join(dir, path_part.to_s) + '.pdf'
        end # each task

        # Copy files into zip
        zip_root_path = "#{td.abbreviation}-pdfs"
        FileHelper.recursively_add_dir_to_zip(zip, dir, zip_root_path)
      end # mktmpdir
    end # zip
    result
  end

  #
  # Create a temp zip file with all submissions for a task
  #
  def get_task_submissions_zip(current_user, td)
    # Get a temp file path
    filename = FileHelper.sanitized_filename("submissions-#{code}-#{td.abbreviation}-#{current_user.username}-files.zip")
    result = Tempfile.new(filename)

    tasks_with_files = td.related_tasks_with_files

    # Create a new zip
    Zip::File.open(result.path, Zip::File::CREATE) do |zip|
      Dir.mktmpdir do |dir|
        # Extract all of the files...
        tasks_with_files.each do |task|
          path_part = if td.is_group_task? && task.group
                        task.group.name.to_s
                      else
                        task.student.username.to_s
                      end

          task.extract_file_from_done(dir, '*',
                                      ->(_task, to_path, name) { File.join(to_path.to_s, path_part, name.to_s) }) # call

          FileUtils.mv Dir.glob("#{dir}/#{path_part}/#{task.id}/*"), File.join(dir, path_part.to_s)
          FileUtils.rm_r "#{dir}/#{path_part}/#{task.id}" if File.directory?("#{dir}/#{path_part}/#{task.id}")
        end # each task

        # Copy files into zip
        zip_root_path = "#{td.abbreviation}-submissions"
        FileHelper.recursively_add_dir_to_zip(zip, dir, zip_root_path)
      end # mktmpdir
    end # zip
    result
  end

  #
  # Create an ILO
  #
  def add_ilo(name, desc, abbr)
    next_num = learning_outcomes.count + 1

    LearningOutcome.create!(
      unit_id: id,
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
    if ilo.ilo_number < new_num
      logger.debug "Moving ILOs up #{ilo.ilo_number} to #{new_num}"
      learning_outcomes.where("ilo_number > #{ilo.ilo_number} and ilo_number <= #{new_num}").find_each { |ilo| ilo.ilo_number -= 1; ilo.save }
    elsif ilo.ilo_number > new_num
      learning_outcomes.where("ilo_number < #{ilo.ilo_number} and ilo_number >= #{new_num}").find_each { |ilo| ilo.ilo_number += 1; ilo.save }
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
  def update_student_max_pct_similar
    # TODO: Remove once max_pct_similar is deleted
    # projects.each do | p |
    #   p.max_pct_similar = p.tasks.maximum(:max_pct_similar)
    #   p.save
    # end
  end

  def create_plagiarism_link(t1, t2, match)
    plk1 = PlagiarismMatchLink.where(task_id: t1.id, other_task_id: t2.id).first
    plk2 = PlagiarismMatchLink.where(task_id: t2.id, other_task_id: t1.id).first

    if plk1.nil? || plk2.nil?
      # Delete old links between tasks
      plk1.destroy unless plk1.nil? ## will delete its pair
      plk2.destroy unless plk2.nil?

      plk1 = PlagiarismMatchLink.create do |plm|
        plm.task = t1
        plm.other_task = t2
        plm.dismissed = false
        plm.pct = match[0][:pct]
      end

      plk2 = PlagiarismMatchLink.create do |plm|
        plm.task = t2
        plm.other_task = t1
        plm.dismissed = false
        plm.pct = match[1][:pct]
      end
    else
      # puts "#{plk1.pct} != #{match[0][:pct]}, #{plk1.pct != match[0][:pct]}"
      # puts "#{plk1.dismissed}"
      plk1.dismissed = false unless plk1.pct == match[0][:pct]
      plk2.dismissed = false unless plk2.pct == match[1][:pct]
      # puts "#{plk1.dismissed}"
      plk1.pct = match[0][:pct]
      plk2.pct = match[1][:pct]
    end

    plk1.plagiarism_report_url = match[0][:url]
    plk2.plagiarism_report_url = match[1][:url]

    plk1.save!
    plk2.save!

    FileHelper.save_plagiarism_html(plk1, match[0][:html])
    FileHelper.save_plagiarism_html(plk2, match[1][:html])
  end

  def update_plagiarism_stats
    moss_key = Doubtfire::Application.secrets.secret_key_moss
    raise "No moss key set. Check ENV['DF_SECRET_KEY_MOSS'] first." if moss_key.nil?
    moss = MossRuby.new(moss_key)

    task_definitions.where(plagiarism_updated: true).find_each do |td|
      td.plagiarism_updated = false
      td.save

      # Get results
      url = td.plagiarism_report_url
      logger.debug "Processing MOSS results #{url}"

      warn_pct = td.plagiarism_warn_pct
      warn_pct = 50 if warn_pct.nil?

      results = moss.extract_results(url, warn_pct, ->(line) { puts line })

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

          g1_tasks.each do |gt1|
            g2_tasks.each do |gt2|
              create_plagiarism_link(gt1, gt2, match)
            end
          end

        else # just link the individuals...
          create_plagiarism_link(t1, t2, match)
        end
      end # end of each result
    end # for each task definition where it needs to be updated

    # TODO: Remove once max_pct_similar is deleted
    # update_student_max_pct_similar()

    self.last_plagarism_scan = Time.zone.now
    save!

    self
  end

  #
  # Extract all done files related to a task definition matching a pattern into a given directory.
  # Returns an array of files
  #
  def add_done_files_for_plagiarism_check_of(td, tmp_path, force, to_check)
    tasks = tasks_for_definition(td)
    tasks_with_files = td.related_tasks_with_files

    # check number of files, and they are new
    if tasks_with_files.count > 1 && (tasks.where('tasks.file_uploaded_at > ?', last_plagarism_scan).select(&:has_pdf).count > 0 || td.updated_at > last_plagarism_scan || force)
      td.plagiarism_checks.each do |check|
        next if check['type'].nil?

        type_data = check['type'].split(' ')
        next if type_data.nil? || (type_data.length != 2) || (type_data[0] != 'moss')

        # extract files matching each pattern
        # -- each pattern
        check['pattern'].split('|').each do |pattern|
          tasks_with_files.each do |t|
            t.extract_file_from_done(tmp_path, pattern, ->(_task, to_path, name) { File.join(to_path.to_s, t.student.username.to_s, name.to_s) })
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
    return unless active

    # need pwd to restore after cding into submission folder (so the files do not have full path)
    pwd = FileUtils.pwd

    begin
      logger.info "Checking plagiarsm for unit #{code} - #{name} (id=#{id})"
      task_definitions.each do |td|
        next if td.plagiarism_checks.empty?
        # Is there anything to check?

        logger.debug "Checking plagiarism for #{td.name} (id=#{td.id})"
        tasks = tasks_for_definition(td)
        tasks_with_files = tasks.select(&:has_pdf)
        next unless tasks_with_files.count > 1 && (tasks.where('tasks.file_uploaded_at > ?', last_plagarism_scan).select(&:has_pdf).count > 0 || td.updated_at > last_plagarism_scan || force)
        # There are new tasks, check these

        logger.debug 'Contacting MOSS for new checks'
        td.plagiarism_checks.each do |check|
          next if check['type'].nil?

          type_data = check['type'].split(' ')
          next if type_data.nil? || (type_data.length != 2) || (type_data[0] != 'moss')

          # Create the MossRuby object
          moss_key = Doubtfire::Application.secrets.secret_key_moss
          raise "No moss key set. Check ENV['DF_SECRET_KEY_MOSS'] first." if moss_key.nil?
          moss = MossRuby.new(moss_key)

          # Set options  -- the options will already have these default values
          moss.options[:max_matches] = 7
          moss.options[:directory_submission] = true
          moss.options[:show_num_matches] = 500
          moss.options[:experimental_server] = false
          moss.options[:comment] = ''
          moss.options[:language] = type_data[1]

          tmp_path = File.join(Dir.tmpdir, 'doubtfire', "check-#{id}-#{td.id}")

          begin
            # Create a file hash, with the files to be processed
            to_check = MossRuby.empty_file_hash
            add_done_files_for_plagiarism_check_of(td, tmp_path, force, to_check)

            FileUtils.chdir(tmp_path)

            # Get server to process files
            logger.debug 'Sending to MOSS...'
            url = moss.check(to_check, ->(line) { puts line })

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
      self.last_plagarism_scan = Time.zone.now
      save!
    ensure
      FileUtils.chdir(pwd) if FileUtils.pwd != pwd
    end

    self
  end

  def import_task_files_from_zip(zip_file)
    task_path = FileHelper.task_file_dir_for_unit self, create = true

    result = {
      success: [],
      errors: [],
      ignored: []
    }

    Zip::File.open(zip_file) do |zip|
      zip.each do |file|
        next unless file.file? # Skip folders
        file_name = File.basename(file.name)
        if (File.extname(file.name) == '.pdf') || (File.extname(file.name) == '.zip')
          found = false
          task_definitions.each do |td|
            next unless /^#{td.abbreviation}/ =~ file_name
            file.extract ("#{task_path}#{FileHelper.sanitized_filename(td.abbreviation)}#{File.extname(file.name)}") { true }
            result[:success] << { row: file.name, message: "Added as task #{td.abbreviation}" }
            found = true
            break
          end

          unless found
            result[:errors] << { row: file.name, message: 'Unable to find a task with matching abbreviation.' }
          end
        else
          result[:ignored] << { row: file.name, message: 'Unknown file type.' }
        end
      end
    end

    result
  end

  #
  # Returns the task ids provided mapped to the number of unresolved
  # plagiarism detections
  #
  def map_task_ids_to_similarity_count(task_ids)
    PlagiarismMatchLink.where('task_id IN (?)', task_ids)
                       .where(dismissed: false)
                       .group(:task_id)
                       .count
  end



  def tasks_as_hash(data)
    task_ids = data.map(&:task_id).uniq
    plagiarism_counts = map_task_ids_to_similarity_count(task_ids)
    data.map do |t|
      {
        id: t.task_id,
        project_id: t.project_id,
        task_definition_id: t.task_definition_id,
        tutorial_id: t.tutorial_id,
        status: TaskStatus.find(t.status_id).status_key,
        completion_date: t.completion_date,
        submission_date: t.submission_date,
        times_assessed: t.times_assessed,
        grade: t.grade,
        quality_pts: t.quality_pts,
        num_new_comments: t.number_unread,
        similar_to_count: plagiarism_counts[t.task_id]
      }
    end
  end

  #
  # Return all tasks from the database for this unit and given user
  #
  def get_all_tasks_for(user)
    student_tasks
      .joins(:task_status)
      .joins("LEFT JOIN task_comments ON task_comments.task_id = tasks.id")
      .joins("LEFT JOIN comments_read_receipts crr ON crr.task_comment_id = task_comments.id AND crr.user_id = #{user.id}")
      .select(
        'tasks.id', 'SUM(case when crr.user_id is null AND NOT task_comments.id is null then 1 else 0 end) as number_unread', 'project_id', 'tasks.id as task_id',
        'task_definition_id', 'task_definitions.start_date as start_date', 'projects.tutorial_id as tutorial_id', 'task_statuses.id as status_id',
        'completion_date', 'times_assessed', 'submission_date', 'portfolio_evidence', 'tasks.grade as grade', 'quality_pts'
      )
      .group(
        'task_statuses.id', 'project_id', 'tutorial_id', 'tasks.id', 'task_definition_id', 'task_definitions.start_date', 'status_id',
        'completion_date', 'times_assessed', 'submission_date', 'portfolio_evidence', 'grade', 'quality_pts'
      )
  end

  #
  # Return the tasks that are waiting for feedback
  #
  def tasks_awaiting_feedback(user)
    get_all_tasks_for(user)
      .where('task_statuses.id IN (:ids)', ids: [ TaskStatus.discuss, TaskStatus.redo, TaskStatus.demonstrate, TaskStatus.fix_and_resubmit ])
      .order('task_definition_id')
  end

  #
  # Return the tasks that should be listed under a tutor's task inbox.
  #
  # Thses tasks are:
  #   - those that have the ready for feedback (rtm) state, or
  #   - where new student comments are > 0
  #
  # They are sorted by a task's "action_date". This defines the last
  # time a task has been "actioned", either the submission date or latest
  # student comment -- whichever is newer.
  #
  def tasks_for_task_inbox(user)
    get_all_tasks_for(user)
      .having('task_statuses.id IN (:ids) OR SUM(case when crr.user_id is null AND NOT task_comments.id is null then 1 else 0 end) > 0', ids: [ TaskStatus.ready_to_mark, TaskStatus.need_help ])
      .order('submission_date ASC, MAX(task_comments.created_at) ASC, task_definition_id ASC')
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
    data = student_tasks
           .joins(:task_status)
           .select('projects.tutorial_id as tutorial_id', 'task_definition_id', 'task_statuses.id as status_id', 'COUNT(tasks.id) as num_tasks')
           .where('task_status_id > 1')
           .group('projects.tutorial_id', 'tasks.task_definition_id', 'status_id')
           .map do |r|
      {
        tutorial_id: r.tutorial_id,
        task_definition_id: r.task_definition_id,
        status: TaskStatus.find(r.status_id).status_key,
        num: r.num_tasks
      }
    end

    # Calculate not started...
    tutorials.each do |t|
      task_definitions.each do |td|
        count = data.select { |r| r[:task_definition_id] == td.id && r[:tutorial_id] == t.id }.map { |r| r[:num] }.inject(:+)
        count = 0 unless count

        num = t.projects.where('projects.enrolled = TRUE AND projects.target_grade >= :grade', grade: td.target_grade).count
        num = 0 unless num

        next unless num - count > 0
        data << {
          tutorial_id: t.id,
          task_definition_id: td.id,
          status: :not_started,
          num: num - count
        }
      end
    end

    result = {}

    task_definitions.each do |td|
      result[td.id] = {}
    end

    data.each do |e|
      unless result[e[:task_definition_id]].key? e[:tutorial_id]
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
    data = active_projects.select('projects.tutorial_id, projects.target_grade, COUNT(projects.id) as num').group('projects.tutorial_id, projects.target_grade').order('projects.tutorial_id, projects.target_grade').map { |r| { tutorial_id: r.tutorial_id, grade: r.target_grade, num: r.num } }
  end

  #
  # Returns only active units
  #
  def self.active_units
    Unit.where(active: true)
  end


  #
  # Returns the basic data used in calculating the student task completion stats
  #
  def _student_task_completion_data_base
    data = student_tasks
           .select('projects.tutorial_id as tutorial_id', 'projects.target_grade as target_grade', 'tasks.project_id', 'Count(tasks.id) as num')
           .where('task_status_id = :complete', complete: TaskStatus.complete.id)
           .group('projects.tutorial_id', 'projects.target_grade', 'tasks.project_id')
           .order('projects.tutorial_id')
    data.map { |r| { tutorial_id: r.tutorial_id, grade: r.target_grade, project: r.project_id, num: r.num } }
  end

  def _calculate_task_completion_stats(data)
    values = data.map { |r| r[:num] }

    if values && values.length > 0
      values.sort!

      median_value = if values.length.even?
                       ((values[values.length / 2] + values[values.length / 2 - 1]) / 2.0).round(1)
                     else
                       values[values.length / 2]
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
  def student_task_completion_stats
    data = _student_task_completion_data_base

    puts data

    result = {}
    result[:unit] = _calculate_task_completion_stats(data)
    result[:tutorial] = {}
    result[:grade] = {}

    tutorials.each do |t|
      result[:tutorial][t.id] = _calculate_task_completion_stats(data.select { |r| r[:tutorial_id] == t.id })
    end

    for i in 0..3 do
      result[:grade][i] = _calculate_task_completion_stats(data.select { |r| r[:grade] == i })
    end

    result
  end

  #
  # Returns a result that maps tutorial_id -> { student outcome map }
  # Where the student outcome map contains each LO and its rating for that student (no student id)
  #
  def student_ilo_progress_stats
    data = student_tasks
           .joins(task_definition: :learning_outcome_task_links)
           .joins(:task_status)
           .select('projects.tutorial_id, projects.id as project_id, task_statuses.id as status_id, task_definitions.target_grade, learning_outcome_task_links.learning_outcome_id, learning_outcome_task_links.rating, COUNT(tasks.id) as num')
           .where('projects.started = TRUE AND learning_outcome_task_links.task_id is NULL')
           .group('projects.tutorial_id, projects.id, task_statuses.id, task_definitions.target_grade, learning_outcome_task_links.learning_outcome_id, learning_outcome_task_links.rating')
           .order('projects.tutorial_id, projects.id')
           .map do |r|
      {
        project_id: r.project_id,
        tutorial_id: r.tutorial_id,
        learning_outcome_id: r.learning_outcome_id,
        rating: r.rating,
        grade: r.target_grade,
        status: TaskStatus.find(r.status_id).status_key,
        num: r.num
      }
    end

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

        current = { project_id: e[:project_id], tutorial_id: e[:tutorial_id], tutorial: [], project: { id: e[:project_id] } }
      elsif e[:project_id] != current[:project_id] # check change of project
        # add the project to the tutorial
        current[:tutorial] << current[:project]

        # reset the
        current[:project_id] = e[:project_id]
        current[:project] = { id: e[:project_id] }
      end

      old_val = 0
      if current[:project].key? e[:learning_outcome_id]
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
      result[tutorial_id_key] = array_of_ilo_scores.map do |map_scores|
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
        values = data.map { |e| e.key?(ilo.id) ? e[ilo.id] : 0 }
        values = values.sort

        median_value = if values.length.even?
                         ((values[values.length / 2] + values[values.length / 2 - 1]) / 2.0).round(1)
                       else
                         values[values.length / 2]
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
    temp = student_ilo_progress_stats.values

    return {} if temp.nil?

    data = temp.reduce(:+)

    _ilo_progress_summary(data)
  end

  def student_grades_csv
    students_with_grades = active_projects.where('grade > 0')

    CSV.generate do |row|
      row << %w(unit_code username student_id grade rationale)
      students_with_grades.each do |project|
        row << [project.unit.code, project.student.username, project.student.student_id, project.grade, project.grade_rationale]
      end
    end
  end

  # Used to calculate the number of assessment each tutor has performed
  def tutor_assessment_csv(options = {})
    CSV.generate(options) do |csv|
      csv << [
        'Username',
        'Tutor Name',
        'Total Tasks Assessed'
      ]

      tasks
        .joins(project: [ { tutorial: { unit_role: :user } } ])
        .select('users.username', 'users.first_name', 'users.last_name', 'SUM(times_assessed) AS total')
        .group('users.username', 'users.first_name', 'users.last_name')
        .each do |r|
          csv << [ r.username, "#{r.first_name} #{r.last_name}", r.total ]
        end
    end
  end

  #----------------------------------------------------------------------------
  # Task updates from offline download/upload
  #----------------------------------------------------------------------------

  #
  # Defines the csv headers for batch download
  #
  def mark_csv_headers
    "Username,Name,Tutorial,Task,Student's Last Comment,Your Last Comment,Status,New Grade,New Quality,Max Quality,New Comment"
  end

  def check_mark_csv_headers
    'Username,Name,Tutorial,Task,Status,New Grade,New Quality,New Comment'
  end

  def readme_text
    path = Rails.root.join('public', 'resources', 'marking_package_readme.txt')
    File.read path
  end

  #
  # Generates a download package of the given tasks
  #
  def generate_batch_task_zip(user, tasks)
    # Reject all tasks not for this unit...
    tasks = tasks.reject { |task| task.project.unit.id != id }

    download_id = "#{Time.new.strftime('%Y-%m-%d')}-#{code}-#{user.username}"
    filename = FileHelper.sanitized_filename("batch_ready_to_mark_#{user.username}.zip")
    output_zip = Tempfile.new(filename)

    # Create a new zip
    Zip::File.open(output_zip.path, Zip::File::CREATE) do |zip|
      csv_str = mark_csv_headers

      # Add individual tasks...
      tasks.select { |t| t.group_submission.nil? }.each do |task|
        # Skip tasks that do not yet have a PDF generated
        next if task.processing_pdf?

        # Add to the template entry string
        student = task.project.student
        mark_col = if task.status == :need_help
                     'need_help'
                   else
                     'rtm'
                   end

        csv_str << "\n#{student.username.tr(',', '_')},#{student.name.tr(',', '_')},#{task.project.tutorial.abbreviation},#{task.task_definition.abbreviation.tr(',', '_')},\"#{task.last_comment_by(task.project.student).gsub(/"/, '""')}\",\"#{task.last_comment_by(user).gsub(/"/, '""')}\",#{mark_col},,,#{task.task_definition.max_quality_pts},"

        src_path = task.portfolio_evidence

        next if src_path.nil? || src_path.empty?
        next unless File.exist? src_path

        # make dst path of "<student id>/<task abbrev>.pdf"
        dst_path = FileHelper.sanitized_path(task.project.student.username.to_s, "#{task.task_definition.abbreviation}-#{task.id}") + '.pdf'
        # now copy it over
        zip.add(dst_path, src_path)
      end

      # Add group tasks...
      tasks.select(&:group_submission).group_by(&:group_submission) .each do |subm, tasks|
        task = tasks.first
        # Skip tasks that do not yet have a PDF generated
        next if task.processing_pdf?

        # Add to the template entry string
        grp = task.group
        next if grp.nil?
        csv_str << "\nGRP_#{grp.id}_#{subm.id},#{grp.name.tr(',', '_')},#{grp.tutorial.abbreviation},#{task.task_definition.abbreviation.tr(',', '_')},\"#{task.last_comment_not_by(user).gsub(/"/, '""')}\",\"#{task.last_comment_by(user).gsub(/"/, '""')}\",rtm,,#{task.task_definition.max_quality_pts},"

        src_path = task.portfolio_evidence

        next if src_path.nil? || src_path.empty?
        next unless File.exist? src_path

        # make dst path of "<student id>/<task abbrev>.pdf"
        dst_path = FileHelper.sanitized_path(grp.name.to_s, "#{task.task_definition.abbreviation}-#{task.id}") + '.pdf'
        # now copy it over
        zip.add(dst_path, src_path)
      end

      # Add marking file
      zip.get_output_stream('marks.csv') { |f| f.puts csv_str }

      # Add readme file
      zip.get_output_stream('readme.txt') { |f| f.puts readme_text }
    end
    output_zip
  end

  #
  # Update the tasks status from the csv and email students
  #
  def update_task_status_from_csv(user, csv_str, success, _ignored, errors)
    done = {}
    # Remove \r -- causes issues with CSV parsing (assume windows \r\n format if present)
    csv_str.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    csv_str.tr!("\r", "\n")
    csv_str.gsub!("\n\n", "\n")

    valid_header = true

    # read data from CSV
    CSV.parse(csv_str, headers: true, return_headers: true,
                       header_converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').downcase unless body.nil? }],
                       converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |task_entry|
      group = nil

      # check the header row
      if task_entry.header_row?
        # find these headers...
        check_mark_csv_headers.split(',').each do |expect_header|
          expect_header.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').downcase!
          unless task_entry.to_hash.keys.include? expect_header
            errors << { row: task_entry, message: "Missing header '#{expect_header}', ensure first row has header information." }
            return false
          end
        end
        # go to the next row if the headers are ok
        next
      end

      # Find the related task definition
      td = task_definitions.select { |td| td.abbreviation.tr(',', '_') == task_entry['task'] }.first
      if td.nil?
        errors << { row: task_entry, message: "Unable to find task with abbreviation #{task_entry['task']}" }
        next
      end

      task = nil
      related_tasks = nil

      # get the task...
      if td.is_group_task?
        unless task_entry['username'] =~ /GRP_\d+_\d+/
          errors << { row: task_entry, message: 'Group username is in the wrong format.' }
          next
        end
        # its a group submission... so find task from group submission
        group_details = /GRP_(\d+)_(\d+)/.match(task_entry['username'])

        subm = GroupSubmission.find_by(id: group_details[2].to_i)
        if subm.nil?
          errors << { row: task_entry, message: 'Unable to find original submission for group task.' }
          next
        end

        task = subm.submitter_task
        if task.nil?
          errors << { row: task_entry, message: 'Unable to find original submission for group task.' }
          next
        end

        group = Group.find(group_details[1].to_i)
        if group.id != task.group.id
          errors << { row: task_entry, message: "Group mismatch (expected task #{td.abbreviation} to match #{task.group.name})" }
          next
        end

        related_tasks = subm.tasks
        owner_text = group.name
      else
        # its an individual task... so find from the project
        project = projects.joins(:user).where('users.username' => task_entry['username']).first
        if project.nil?
          errors << { row: task_entry, message: 'Unable to find student project for this task.' }
          next
        end

        task = project.task_for_task_definition(td)
        if task.nil?
          errors << { row: task_entry, message: "Unable to find task for #{task_entry['task']} not found" }
          next
        end

        related_tasks = [ task ]
        owner_text = project.user.name
      end

      unless AuthorisationHelpers.authorise? user, task, :put
        errors << { row: task_entry, error: 'You do not have permission to assess this task.' }
        next
      end

      begin
        task.trigger_transition(trigger: task_entry['status'], by_user: user, quality: task_entry['new quality'].to_i) # saves task
        task.grade_task(task_entry['new grade']) # try to grade task if need be

        if !(task_entry['new comment'].nil? || task_entry['new comment'].empty?)
          task.add_text_comment user, task_entry['new comment']
          success << { row: task_entry, message: "Updated task #{task.task_definition.abbreviation} for #{owner_text}" }
          success << { row: {}, message: "Added comment to #{task.task_definition.abbreviation} for #{owner_text}" }
        else
          success << { row: task_entry, message: "Updated task #{task.task_definition.abbreviation} for #{owner_text}" }
        end
      rescue Exception => e
        errors << { row: task_entry, message: e.message }
        next
      end

      related_tasks.each do |task|
        # add to done projects for emailing
        done[task.project] = [] if done[task.project].nil?
        done[task.project] << task
      end
    end

    # send emails...
    begin
      done.each do |project, tasks|
        logger.info "Checking feedback email for project #{project.id}"
        if project.student.receive_feedback_notifications
          logger.info "Emailing feedback notification to #{project.student.name}"
          PortfolioEvidenceMailer.task_feedback_ready(project, tasks).deliver
        end
      end
    rescue => e
      logger.error "Failed to send emails from feedback submission. Rescued with error: #{e.message}"
    end

    true
  end

  #
  # Uploads a batch package back into doubtfire
  #
  def upload_batch_task_zip_or_csv(user, file)
    success = []
    errors = []
    ignored = []

    type = mime_type(file.tempfile.path)

    # check mime is correct before uploading
    accept = ['text/', 'text/plain', 'text/csv', 'application/zip', 'multipart/x-gzip', 'multipart/x-zip', 'application/x-gzip', 'application/octet-stream']
    unless mime_in_list?(file.tempfile.path, accept)
      errors << { row: {}, message: "File given is not a zip or csv file - detected #{type}" }
      return {
        success:  success,
        ignored:  ignored,
        errors:   errors
      }
    end

    if type.start_with?('text/', 'text/plain', 'text/csv')
      update_task_status_from_csv(user, File.open(file.tempfile.path).read, success, ignored, errors)
    else
      # files are extracted to a temp dir first
      i = 0
      tmp_dir = File.join(Dir.tmpdir, 'doubtfire', 'batch', i.to_s)

      while Dir.exist? tmp_dir
        i += 1
        tmp_dir = File.join(Dir.tmpdir, 'doubtfire', 'batch', i.to_s)
      end

      logger.debug "Created temp directory for batch zip at #{tmp_dir}"

      FileUtils.mkdir_p(tmp_dir)

      begin
        Zip::File.open(file.tempfile.path) do |zip|
          # Find the marking file within the directory tree
          marking_file = zip.glob('**/marks.csv').first

          # No marking file found
          if marking_file.nil?
            errors << { row: {}, message: 'No marks.csv contained in zip.' }
            return {
              success:  success,
              ignored:  ignored,
              errors:   errors
            }
          end

          # Read the csv
          csv_str = marking_file.get_input_stream.read
          csv_str.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless csv_str.nil?

          # Update tasks and email students
          unless update_task_status_from_csv(user, csv_str, success, ignored, errors)
            errors << { row: {}, message: 'Aborting import as mark.csv was not processed successfully.' }
            return {
              success:  success,
              ignored:  ignored,
              errors:   errors
            }
          end

          # read keys from CSV - to check that files exist in csv
          entry_data = CSV.parse(csv_str, headers: true,
                                          header_converters: [->(i) { i.nil? ? '' : i }, :downcase],
                                          converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }])

          # Copy over the updated/marked files to the file system
          zip.each do |file|
            # Skip processing marking file
            next if File.basename(file.name) == 'marks.csv' || File.basename(file.name) == 'readme.txt'

            # Test filename pattern
            if (/.*-\d+.pdf/i =~ File.basename(file.name)) != 0
              if file.name[-1] != '/'
                ignored << { row: "File #{file.name}", message: 'Does not appear to be a task PDF.' }
              end
              next
            end
            if (/\._.*/ =~ File.basename(file.name)) == 0
              ignored << { row: "File #{file.name}", message: 'Does not appear to be a task PDF.' }
              next
            end

            # Extract the id from the filename
            task_id_from_filename = File.basename(file.name, '.pdf').split('-').last
            task = Task.find_by(id: task_id_from_filename)
            if task.nil?
              ignored << { row: "File #{file.name}", message: 'Unable to find associated task.' }
              next
            end

            # Ensure that this task's id is inside entry_data
            task_entry = entry_data.select { |t| t['task'] == task.task_definition.abbreviation.tr(',', '_') && t['username'] == task.project.user.username }.first
            if task_entry.nil?
              # error!({"error" => "File #{file.name} has a mismatch of task id ##{task.id} (this task id does not exist in marks.csv)"}, 403)
              errors << { row: "File #{file.name}", message: "Task id #{task.id} not in marks.csv" }
              next
            end

            if task.unit != self
              errors << { row: "File #{file.name}", message: 'This task does not relate to this unit.' }
              next
            end

            # Can the user assess this task?
            unless AuthorisationHelpers.authorise? user, task, :put
              errors << { row: "File #{file.name}", error: "You do not have permission to assess task with id #{task.id}" }
              next
            end

            # Read into the task's portfolio_evidence path the new file
            tmp_file = File.join(tmp_dir, File.basename(file.name))
            task.portfolio_evidence = task.final_pdf_path

            # get file out of zip... to tmp_file
            file.extract(tmp_file) { true }

            # copy tmp_file to dest
            if FileHelper.copy_pdf(tmp_file, task.portfolio_evidence)
              if task.group.nil?
                success << { row: "File #{file.name}", message: "Replace PDF of task #{task.task_definition.abbreviation} for #{task.student.name}" }
              else
                success << { row: "File #{file.name}", message: "Replace PDF of group task #{task.task_definition.abbreviation} for #{task.group.name}" }
              end
              FileUtils.rm tmp_file
            else
              errors << { row: "File #{file.name}", message: 'The file does not appear to be a valid PDF.' }
              next
            end
          end
        end
      rescue
        # FileUtils.cp(file.tempfile.path, Doubtfire::Application.config.student_work_dir)
        raise
      end

      # Remove the extract dir
      FileUtils.rm_rf tmp_dir
    end

    {
      success:  success,
      ignored:  ignored,
      errors:   errors
    }
  end

  def send_weekly_status_emails(summary_stats)

    summary_stats[:unit] = self
    summary_stats[:unit_week_comments] = comments.where("task_comments.created_at > :start AND task_comments.created_at < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count
    summary_stats[:unit_week_engagements] = task_engagements.where("task_engagements.engagement_time > :start AND task_engagements.engagement_time < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count
    summary_stats[:revert_count] = 0
    summary_stats[:revert] = {}
    summary_stats[:staff] = {}

    days_to_end_of_unit = (end_date.to_date - DateTime.now).to_i
    days_from_start_of_unit = (DateTime.now - start_date.to_date).to_i

    return if days_from_start_of_unit < 4 || days_to_end_of_unit < 0

    staff.each do |ur|
      summary_stats[:revert][ur.user] = []
    end

    active_projects.each do |project|
      project.send_weekly_status_email(summary_stats, days_from_start_of_unit > 28 && days_to_end_of_unit > 14 )
    end

    summary_stats[:num_students_without_tutors] = active_projects.where(tutorial_id: nil).count

    staff.each do |ur|
      ur.populate_summary_stats(summary_stats)
    end

    staff.each do |ur|
      ur.send_weekly_status_email(summary_stats)
    end

    summary_stats[:staff] = {}

  end
end
