require 'csv'
require 'bcrypt'
require 'json'
require 'moss_ruby'
require 'csv_helper'
require 'grade_helper'

class Unit < ApplicationRecord
  include ApplicationHelper
  include FileHelper
  include LogHelper
  include MimeCheckHelpers
  include CsvHelper

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
      :download_grades,
      :exceed_capacity
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
      :download_grades,
      :rollover_unit,
      :exceed_capacity,
      :perform_overseer_assessment_test
    ]

    # What can admin do with units?
    admin_role_permissions = [
      :get_unit,
      :get_students,
      :enrol_student,
      :upload_csv,
      :rollover_unit,
      :change_project_enrolment,
      :update,
      :employ_staff,
      :add_tutorial,
      :add_task_def,
      :download_stats,
      :download_unit_csv,
      :download_grades,
      :exceed_capacity
    ]

    # What can auditors do with units?
    auditor_role_permissions = [
      :get_unit,
      :get_students,
      :download_stats,
    ]

    # What can other users do with units?
    nil_role_permissions = []

    # Return permissions hash
    {
      student: student_role_permissions,
      tutor: tutor_role_permissions,
      convenor: convenor_role_permissions,
      admin: admin_role_permissions,
      auditor: auditor_role_permissions,
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
    elsif user.has_auditor_capability?
      Role.auditor
    elsif user.has_admin_capability?
      Role.admin
    else
      nil
    end
  end

  # Ensure before destroy is above relations - as this needs to clear main convenor before unit roles are deleted
  before_destroy do
    update(main_convenor_id: nil)
    delete_associated_files
  end

  after_update :propogate_date_changes_to_tasks, if: :saved_change_to_start_date?

  # Model associations.
  # When a Unit is destroyed, any TaskDefinitions, Tutorials, and ProjectConvenor instances will also be destroyed.
  has_many :projects, dependent: :destroy # projects first to remove tasks
  has_many :active_projects, -> { where enrolled: true }, class_name: 'Project'
  has_many :group_sets, dependent: :destroy # group sets next to remove groups
  has_many :task_definitions, -> { order 'start_date ASC, abbreviation ASC' }, dependent: :destroy
  has_many :tutorials, dependent: :destroy # tutorials need groups and tasks deleted before it...
  has_many :tutorial_streams, dependent: :destroy
  has_many :unit_roles, dependent: :destroy
  has_many :learning_outcomes, dependent: :destroy
  has_many :comments, through: :projects

  has_many :tasks, through: :projects
  has_many :groups, through: :group_sets
  has_many :tutorial_enrolments, through: :tutorials
  has_many :group_memberships, through: :groups
  has_many :teaching_staff, through: :unit_roles, class_name: 'User', source: 'user'
  has_many :learning_outcome_task_links, through: :task_definitions
  has_many :task_engagements, through: :projects

  has_many :convenors, -> { joins(:role).where('roles.name = :role', role: 'Convenor') }, class_name: 'UnitRole'
  has_many :staff, ->     { joins(:role).where('roles.name = :role_convenor or roles.name = :role_tutor', role_convenor: 'Convenor', role_tutor: 'Tutor') }, class_name: 'UnitRole'

  # Unit has a teaching period
  belongs_to :teaching_period, optional: true

  belongs_to :main_convenor, class_name: 'UnitRole', optional: true

  belongs_to :draft_task_definition, class_name: 'TaskDefinition', optional: true

  belongs_to :overseer_image, optional: true

  validates :name, :description, :start_date, :end_date, presence: true

  validates :description, length: { maximum: 4095, allow_blank: true }

  validates :start_date, presence: true
  validates :end_date, presence: true

  validates :code, uniqueness: { scope: :teaching_period, message: "%{value} already exists in this teaching period" }, if: :has_teaching_period?
  validates :extension_weeks_on_resubmit_request, :numericality => { :greater_than_or_equal_to => 0 }

  validate :validate_end_date_after_start_date
  validate :ensure_teaching_period_dates_match, if: :has_teaching_period?

  validate :ensure_main_convenor_is_appropriate

  # Portfolio autogen date validations, must be after start date and before or equal to end date
  validate :autogen_date_within_unit_active_period, if: -> { start_date_changed? || end_date_changed? || teaching_period_id_changed? || portfolio_auto_generation_date_changed? }

  scope :current,               -> { current_for_date(Time.zone.now) }
  scope :current_for_date,      ->(date) { where('start_date <= ? AND end_date >= ?', date, date) }
  scope :not_current,           -> { not_current_for_date(Time.zone.now) }
  scope :not_current_for_date,  ->(date) { where('start_date > ? OR end_date < ?', date, date) }
  scope :set_active,            -> { where('active = ?', true) }
  scope :set_inactive,          -> { where('active = ?', false) }

  def docker_image_name_tag
    return nil if overseer_image.nil?

    overseer_image.tag
  end

  def add_tutorial_stream(name, abbreviation, activity_type)
    tutorial_stream = TutorialStream.new
    tutorial_stream.name = name
    tutorial_stream.abbreviation = abbreviation
    tutorial_stream.unit = self
    tutorial_stream.activity_type = activity_type
    tutorial_stream.save!

    # add after save to ensure valid tutorial stream
    self.tutorial_streams << tutorial_stream

    tutorial_stream
  end

  def update_tutorial_stream(existing_tutorial_stream, name, abbreviation, activity_type)
    existing_tutorial_stream.name = name if name.present?
    existing_tutorial_stream.abbreviation = abbreviation if abbreviation.present?
    existing_tutorial_stream.activity_type = activity_type if activity_type.present?
    existing_tutorial_stream.save!
    existing_tutorial_stream
  end

  def teaching_period_id=(tp_id)
    self.teaching_period = TeachingPeriod.find(tp_id)
    super(tp_id)
  end

  def teaching_period=(tp)
    if tp.present?
      write_attribute(:start_date, tp.start_date)
      write_attribute(:end_date, tp.end_date)
      write_attribute(:teaching_period_id, tp.id)
    end
    super(tp)
  end

  def has_teaching_period?
    self.teaching_period.present?
  end

  def ensure_teaching_period_dates_match
    if read_attribute(:start_date) != teaching_period.start_date
      errors.add(:start_date, "should match teaching period date")
    end
    if read_attribute(:end_date) != teaching_period.end_date
      errors.add(:end_date, "should match teaching period date")
    end
  end

  def ensure_main_convenor_is_appropriate
    return if main_convenor_id.nil?

    errors.add(:main_convenor, "must be a staff member from unit") unless id == main_convenor.unit_id
    errors.add(:main_convenor, "must be configured to administer unit") unless main_convenor.is_convenor?
    errors.add(:main_convenor, "must be capable of administering units - ensure user has appropriate permissions (contact admin staff to update)") unless main_convenor_user.has_convenor_capability?
  end

  def validate_end_date_after_start_date
    if end_date.present? && start_date.present? && end_date < start_date
      errors.add(:end_date, "should be after the Start date")
    end
  end

  def autogen_date_within_unit_active_period
    if [start_date, end_date, portfolio_auto_generation_date].all?(&:present?) && !(start_date < portfolio_auto_generation_date && portfolio_auto_generation_date <= end_date)
      errors.add(:portfolio_auto_generation_date, "should be after unit start date and before unit end date")
    end
  end

  def rollover(teaching_period, start_date, end_date)
    new_unit = self.dup

    if teaching_period.present?
      new_unit.teaching_period = teaching_period
    else
      new_unit.start_date = start_date
      new_unit.end_date = end_date
    end

    if self.portfolio_auto_generation_date.present?
      # Update the portfolio auto generation date to be the same day of the week and week number as the old date
      new_unit.portfolio_auto_generation_date = new_unit.date_for_week_and_day(week_number(self.portfolio_auto_generation_date), Date::ABBR_DAYNAMES[self.portfolio_auto_generation_date.wday])
    end

    # Clear main convenor - do not use old role id
    new_unit.main_convenor_id = nil

    new_unit.save!

    # Only employ the main convenor... they can add additional staff
    new_unit.employ_staff main_convenor_user, Role.convenor

    # Duplicate tutorial streams
    tutorial_streams.each do |tutorial_stream|
      new_unit.tutorial_streams << tutorial_stream.dup
    end

    # Duplicate group sets - before tasks as some tasks are group tasks
    group_sets.each do |group_set|
      new_unit.group_sets << group_set.dup
    end

    # Duplicate task definitions
    task_definitions.each do |td|
      new_td = td.copy_to(new_unit)

      # Update default task definition if necessary
      if self.draft_task_definition == td
        new_unit.update(draft_task_definition: new_td)
      end
    end

    # Duplicate unit learning outcomes
    learning_outcomes.each do |learning_outcome|
      new_unit.learning_outcomes << learning_outcome.dup
    end

    # Duplicate alignments
    task_outcome_alignments.each do |align|
      align.duplicate_to(new_unit)
    end

    new_unit
  end

  def ordered_ilos
    learning_outcomes.order(:ilo_number)
  end

  def task_outcome_alignments
    learning_outcome_task_links.where('task_id is NULL')
  end

  def student_tasks
    tasks.joins(:task_definition).where('projects.enrolled = TRUE')
  end

  def self.for_user_admin(user)
    if user.has_admin_capability?
      Unit.all
    elsif user.has_auditor_capability?
      # Limit range of units that the auditor has access to
      earliest_unit_date = Doubtfire::Application.config.auditor_unit_start_after || (Date.today - 1.year)
      latest_unit_date = Doubtfire::Application.config.auditor_unit_start_before || (Date.today - 10.weeks)
      Unit.all.where('start_date >= :earliest_unit_date AND start_date <= :latest_unit_date', earliest_unit_date: earliest_unit_date, latest_unit_date: latest_unit_date)
    else
      Unit.joins(:unit_roles).where('unit_roles.user_id = :user_id AND unit_roles.role_id = :convenor_role', user_id: user.id, convenor_role: Role.convenor.id)
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

  def main_convenor_user
    main_convenor.user
  end

  def students
    projects
  end

  def student_query(enrolled)
    q = projects
        .joins(:user)
        .joins('LEFT OUTER JOIN tasks ON projects.id = tasks.project_id')
        .joins('LEFT JOIN task_definitions ON tasks.task_definition_id = task_definitions.id')
        .joins('LEFT OUTER JOIN plagiarism_match_links ON tasks.id = plagiarism_match_links.task_id')
        .joins('LEFT OUTER JOIN tutorial_enrolments ON tutorial_enrolments.project_id = projects.id')
        .joins('LEFT OUTER JOIN tutorials ON tutorials.id = tutorial_enrolments.tutorial_id')
        .joins('LEFT OUTER JOIN tutorial_streams ON tutorials.tutorial_stream_id = tutorial_streams.id')
        .group(
          'projects.id',
          'projects.target_grade',
          'projects.task_stats',
          'projects.submitted_grade',
          'projects.enrolled',
          'projects.campus_id',
          'users.first_name',
          'users.last_name',
          'users.username',
          'users.id',
          'users.email',
          'projects.portfolio_production_date',
          'projects.compile_portfolio',
          'projects.grade',
          'projects.grade_rationale',
        )
        .select(
          'projects.id AS project_id',
          'projects.enrolled AS enrolled',
          'projects.task_stats AS task_stats',
          'projects.campus_id AS campus_id',
          'users.first_name AS first_name',
          'users.last_name AS last_name',
          'users.nickname AS nickname',
          'users.student_id AS student_id',
          'users.username AS username',
          'users.id AS user_id',
          'users.email AS student_email',
          'projects.target_grade AS target_grade',
          'projects.submitted_grade AS submitted_grade',
          'projects.compile_portfolio AS compile_portfolio',
          'projects.grade AS grade',
          'projects.grade_rationale AS grade_rationale',
          'projects.portfolio_production_date AS portfolio_production_date',
          'MAX(CASE WHEN plagiarism_match_links.dismissed = FALSE THEN plagiarism_match_links.pct ELSE 0 END) AS plagiarism_match_links_max_pct',
          # Get tutorial for each stream in unit
          *tutorial_streams.map { |s| "MAX(CASE WHEN tutorials.tutorial_stream_id = #{s.id} OR tutorials.tutorial_stream_id IS NULL THEN tutorials.id ELSE NULL END) AS tutorial_#{s.id}" },
          # Get tutorial for case when no stream
          "MAX(CASE WHEN tutorial_streams.id IS NULL THEN tutorials.id ELSE NULL END) AS tutorial"
        )
        .order('users.first_name')

    if enrolled
      q = q.where('projects.enrolled = TRUE')
    else
      q = q.where('projects.enrolled = FALSE')
    end

    map_stats = lambda { |t| begin t.task_stats.present? ? JSON.parse(t.task_stats) : {} rescue {} end }

    q.map do |t|
      result = {
        id: t.project_id,
        enrolled: t.enrolled,
        campus_id: t.campus_id,
        student: {
          id: t.user_id,
          student_id: t.student_id,
          username: t.username,
          email: t.student_email,
          first_name: t.first_name,
          last_name: t.last_name,
          nickname: t.nickname
        },
        target_grade: t.target_grade,
        submitted_grade: t.submitted_grade,
        compile_portfolio: t.compile_portfolio,
        grade: t.grade,
        grade_rationale: t.grade_rationale,
        max_pct_copy: t.plagiarism_match_links_max_pct,
        has_portfolio: !t.portfolio_production_date.nil?,
        stats: map_stats.call(t),
        tutorial_enrolments: tutorial_streams.map do |s|
          {
            stream_abbr: s.abbreviation,
            tutorial_id: t["tutorial_#{s.id}"]
          }
        end
      }

      if tutorial_streams.empty?
        result[:tutorial_enrolments] = [{ tutorial_id: t['tutorial'] }]
      end
      result
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

      if main_convenor.nil?
        update!(main_convenor_id: new_staff.id)
      end

      new_staff
    end
  end

  # Adds a user to this project.
  def enrol_student(user, campus)
    # Validates that a student is not already assigned to the unit
    existing_project = projects.where('user_id=:user_id', user_id: user.id).first
    if existing_project
      if existing_project.enrolled == false
        existing_project.enrolled = true
        existing_project.campus = campus
        existing_project.save!
      end

      return existing_project
    end

    Project.create!(
      user_id: user.id,
      unit_id: id,
      task_stats: Project::DEFAULT_TASK_STATS,
      campus: campus
    )
  end

  def tutorial_with_abbr(abbr)
    tutorials.where(abbreviation: abbr).first
  end

  # Use institution settings to sync student enrolments
  def sync_enrolments
    result = Doubtfire::Application.config.institution_settings.sync_enrolments(self)

    return if result.nil?

    logger.info "#{code} - Import success for #{result[:success].count} students" unless result[:success].count == 0
    logger.info "#{code} - Skipped #{result[:ignored].count} students" unless result[:ignored].count == 0
    logger.info "#{code} - Errors #{result[:errors].count} students" unless result[:errors].count == 0

    result[:errors].each do |err|
      logger.error "#{err[:message]} --> #{err[:row]}"
    end
    logger.info "---" unless result[:errors].count == 0

    result
  end

  #
  # Imports users into a project from CSV file.
  # Format: Unit Code, Student ID,First Name, Surname, email, tutorial, campus
  # Expected columns: unit_code, username, first_name, last_name, email, tutorial, campus
  #
  def import_users_from_csv(file)
    success = []
    errors = []
    ignored = []

    result = {
      success: success,
      ignored: ignored,
      errors: errors
    }

    csv = CSV.new(File.read(file), headers: true,
                                   header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                   converters: [->(i) { i.nil? ? '' : i }, ->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }])

    # Read the header row to determine what kind of file it is
    if csv.header_row?
      csv.shift
    else
      errors << { row: [], message: "Header row missing" }
      return
    end

    # Check if these headers should be processed by institution file or from DF format
    if Doubtfire::Application.config.institution_settings.are_headers_institution_users? csv.headers
      import_settings = Doubtfire::Application.config.institution_settings.user_import_settings_for(csv.headers)
    else
      if tutorial_streams.count > 0
        stream_names = tutorial_stream_abbr.map { |abbr| abbr.downcase }
      else
        stream_names = ['tutorial']
      end

      # Settings include:
      #   missing_headers_lambda - lambda to check if row is missing key data
      #   fetch_row_data_lambda - lambda to convert row from csv to required import data
      #   replace_existing_tutorial - boolean to indicate if tutorials in csv override ones in doubtfire
      #   replace_existing_campus - boolean to indicate if campus in csv override ones in doubtfire
      import_settings = {
        missing_headers_lambda: ->(row) {
          missing_headers(row, %w(unit_code username student_id first_name last_name email campus))
          missing_headers(row, stream_names)
        },
        fetch_row_data_lambda: ->(row, unit) {
          tutorials = []

          stream_names.each do |stream|
            tutorials << row[stream] if row[stream].present?
          end

          {
            unit_code: row['unit_code'],
            username: row['username'],
            student_id: row['student_id'],
            first_name: row['first_name'],
            nickname: nil,
            last_name: row['last_name'],
            email: row['email'],
            enrolled: true,
            tutorials: tutorials,
            campus: row['campus']
          }
        },
        replace_existing_tutorial: true,
        replace_existing_campus: true
      }
    end

    student_list = []

    # Loop over csv rows converting to hash values
    CSV.foreach(file, headers: true,
                      header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                      converters: [->(i) { i.nil? ? '' : i }, ->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]) do |row|
      # Check data has headers
      missing = import_settings[:missing_headers_lambda].call(row)
      if missing.count > 0
        errors << { row: row, message: "Missing headers: #{missing.join(', ')}" }
        next
      end

      begin
        # Convert to hash...
        row_data = import_settings[:fetch_row_data_lambda].call(row, self)
        row_data[:row] = row
        # Store in list...
        student_list << row_data
      rescue Exception => e
        errors << { row: row, message: e.message }
      end
    end # for each csv row

    # Now process the listt
    sync_enrolment_with(student_list, import_settings, result)
  end

  # Sync the unit enrolment details eith the list of enrolment data. The enrolment data
  # is a list to hashes. Each hash contains the following:
  #     -:row the string data associated with the change
  #     -:username the student username
  #     -:student_id
  #     -:first_name
  #     -:last_name
  #     -:nickname
  #     -:email
  #     -:tutorial_codes
  #     -:enrolled (boolean)
  #     -:campus
  # This will ensure that there is only one listing per student in the data that
  # is then used to update the student enrolments.
  #
  # Settings include:
  #   missing_headers_lambda - lambda to check if row is missing key data
  #   fetch_row_data_lambda - lambda to convert row from csv to required import data
  #   replace_existing_tutorial - boolean to indicate if tutorials in csv override ones in doubtfire
  #   replace_existing_campus - boolean to indicate if campus in csv override ones in doubtfire
  def sync_enrolment_with(enrolment_data, import_settings, result)
    # Get lists for reporting results
    success = result[:success]
    errors = result[:errors]
    ignored = result[:ignored]

    # Record changes ready to process - map on username to ensure only one option per user
    # enrol will override withdraw
    changes = {}

    # For each row
    enrolment_data.each do |row_data|
      begin
        if row_data[:username].nil?
          ignored << { row: row, message: "Skipping row with missing username" }
          next
        end

        unit_code = row_data[:unit_code]

        # Check it is one of the unit codes
        unless code == unit_code || code.split('/').include?(unit_code)
          ignored << { row: row_data[:row], message: "Invalid unit code. #{unit_code} does not match #{code}" }
          next
        end

        # now record changes...
        username = row_data[:username].downcase

        # do we already have this user?
        if changes.key? username
          if row_data[:enrolled] # they should be enrolled - record that... overriding anything else
            # record previous row as ignored
            ignored << { row: changes[username][:row], message: "Skipping duplicate role - ensuring enrolled" }
            changes[username] = row_data
          else
            # record this row as skipped
            ignored << { row: row_data[:row], message: "Skipping duplicate role" }
          end
        else # dont have the user so record them - will add to result when processed
          changes[username] = row_data
        end
      rescue Exception => e
        errors << { row: row_data[:row], message: e.message }
      end
    end # for each csv row

    update_student_enrolments(changes, import_settings, result)
  end # csv import

  # Apply enrolment changes. The changes parameter should be:
  # - A hash
  # - Key = student username
  # - Value = hash of
  #     -:row the string data associated with the change
  #     -:username the student username (also the key to this data)
  #     -:student_id
  #     -:first_name
  #     -:last_name
  #     -:nickname
  #     -:email
  #     -:tutorials array of [tutorial_code, ...]
  #     -:enrolled
  #     -:campus
  # Import settings is:
  # - A hash
  # - :replace_existing_tutorial boolean
  # - :replace_existing_campus boolean
  #
  # Returns hash with :success, :ignored, :errors
  def update_student_enrolments(changes, import_settings, result)
    tutorial_cache = {}
    # Get lists for reporting results
    success = result[:success]
    errors = result[:errors]
    ignored = result[:ignored]

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
        tutorials = row_data[:tutorials]
        campus_data = row_data[:campus]

        # If either first or last name is nil... copy over the other component
        first_name = first_name || last_name
        last_name = last_name || first_name
        nickname = nickname || first_name

        if email !~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
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

        # Find the campus
        campus = campus_data.present? ? Campus.find_by_abbr_or_name(campus_data) : nil
        if campus_data.present? && campus.nil?
          errors << { row: row, message: "Unable to find campus (#{campus_data})" }
          next
        end

        # It is an enrolment... so first find the user
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
          if (project_participant.student_id.nil? || project_participant.student_id.empty? || project_participant.student_id != student_id) && student_id.present?
            project_participant.student_id = student_id
            project_participant.save!
          end

          # Clear success message...
          success_message = ''

          # Now find the project for the user
          user_project = projects.where(user_id: project_participant.id).first

          # Add the user to the project (if not already in there)
          if user_project.nil?
            # Enrol user...
            user_project = enrol_student(project_participant, campus)
            success_message = 'Enrolled student'
            new_project = true
          else
            new_project = false # We are updating existing project
            # update enrolment... if currently not enrolled
            unless user_project.enrolled
              user_project.enrolled = true
              user_project.save
              success_message << 'Re-enrolled student.'
            end

            # update campus if available, and either not provided and available or should be replaced
            if campus.present? && (user_project.campus_id.nil? || (import_settings[:replace_existing_campus] && user_project.campus_id != campus.id))
              user_project.campus_id = campus.id
              user_project.save
              success_message << 'Campus updated.'
            end
          end

          # Only update if we will change tutorial enrolments... or no enrolment
          if import_settings[:replace_existing_tutorial] || new_project || user_project.tutorial_enrolments.count == 0

            # Now loop through the tutorials and enrol the student...
            tutorials.each do |tutorial_code|
              # find the tutorial for the user
              tutorial = tutorial_cache[tutorial_code] || tutorial_with_abbr(tutorial_code)
              tutorial_cache[tutorial_code] ||= tutorial

              if tutorial.present?
                # Use tutorial as we have it :)
                begin
                  user_project.enrol_in tutorial
                  success_message << ' Enrolled in ' << tutorial.abbreviation
                rescue Exception => e
                  success_message << " UNABLE TO enroll in #{tutorial.abbreviation} #{e.message}"
                end
              end
            end
          end

          if success_message.empty?
            ignored << { row: row, message: 'No change.' }
          else
            success << { row: row, message: success_message }
          end
        else
          errors << { row: row, message: "Student record is invalid. #{project_participant.errors.full_messages.first}" }
        end
      rescue Exception => e
        errors << { row: row, message: e.message }
      end
    end

    result
  end

  # Use the values in the CSV to set the enrolment of these
  # students to false for this unit.
  # CSV should contain just the usernames to withdraw
  def unenrol_users_from_csv(file)
    logger.info "Initiating withdraw of students from unit #{id} using CSV"

    success = []
    errors = []
    ignored = []

    data = read_file_to_str(file)

    CSV.parse(data,
              headers: true,
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
      errors: errors
    }
  end

  def export_users_to_csv
    streams = tutorial_streams
    grp_sets = group_sets

    CSV.generate do |csv|
      csv <<  (%w(unit_code campus username student_id preferred_name first_name last_name email) +
              (streams.count > 0 ? streams.map { |t| t.abbreviation } : ['tutorial']))

      active_projects
        .joins(
          :unit,
          :campus,
          'INNER JOIN users ON projects.user_id = users.id',
          'LEFT OUTER JOIN tutorial_streams ON tutorial_streams.unit_id = units.id',
          'LEFT OUTER JOIN tutorial_enrolments ON tutorial_enrolments.project_id = projects.id',
          'LEFT OUTER JOIN tutorials ON tutorial_enrolments.tutorial_id = tutorials.id'
        ).select(
          'projects.id as project_id', 'users.student_id as student_id', 'users.username as username', 'users.first_name as first_name',
          'users.last_name as last_name', 'users.email as email', 'users.nickname as nickname', 'campuses.abbreviation as campus_abbreviation',
          # Get tutorial for each stream in unit
          *streams.map { |s| "MAX(CASE WHEN tutorials.tutorial_stream_id = #{s.id} OR tutorials.tutorial_stream_id IS NULL THEN tutorials.abbreviation ELSE NULL END) AS tutorial_#{s.id}" },
          # Get tutorial for case when no stream
          "MAX(CASE WHEN tutorial_streams.id IS NULL THEN tutorials.abbreviation ELSE NULL END) AS tutorial"
        ).group(
          'projects.id', 'student_id', 'username', 'first_name', 'nickname', 'last_name', 'email', 'campus_abbreviation'
        ).each do |row|
          csv << ([
            code,
            row['campus_abbreviation'],
            row['username'],
            row['student_id'],
            row['nickname'],
            row['first_name'],
            row['last_name'],
            row['email']
          ] + [1].map do
                if streams.empty?
                  [row['tutorial']]
                else
                  streams.map { |ts| row["tutorial_#{ts.id}"] }
                end
              end.flatten)
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

    data = read_file_to_str(file)

    CSV.parse(data,
              headers: true,
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

    data = read_file_to_str(file)

    CSV.parse(data,
              headers: true,
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
      errors: errors
    }
  end

  # Import the actual groups from a csv - no students...
  def import_groups_from_csv(group_set, file)
    success = []
    errors = []
    ignored = []

    logger.info "Starting import of group for #{group_set.name} for #{code}"

    data = read_file_to_str(file)

    CSV.parse(data,
              headers: true,
              header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
              converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      next if row[0] =~ /^(group_name)|(name)/ # Skip header

      begin
        missing = missing_headers(row, %w(group_name tutorial capacity_adjustment))
        if missing.count > 0
          errors << { row: row, message: "Missing headers: #{missing.join(', ')}" }
          next
        end

        change = ''

        # Get name from csv
        group_name = row['group_name'].strip unless row['group_name'].nil?

        # Find or create the group object
        grp = group_set.groups.find_or_create_by(name: group_name)

        # Find the tutorial
        tutorial_abbr = row['tutorial'].strip unless row['tutorial'].nil?
        tutorial = tutorial_with_abbr(tutorial_abbr)

        if tutorial.nil?
          change += ' Created new tutorial.'

          campus_data = row['campus'].strip unless row['campus'].nil?
          campus = Campus.find_by_abbr_or_name(campus_data)

          tutorial = add_tutorial(
            'Monday',
            '8:00am',
            'TBA',
            main_convenor_user,
            campus,
            nil, # capacity
            tutorial_abbr
          )
        end

        # If it is new we need to load details from the csv
        if grp.new_record?
          # Get group details
          change += ' Created new group.'
        end

        # Update group details
        grp.tutorial = tutorial
        grp.capacity_adjustment = row['capacity_adjustment'].strip.to_i unless row['capacity_adjustment'].nil?
        grp.save!

        success << { row: row, message: "Setup #{grp.name}.#{change}" }
      rescue Exception => e
        errors << { row: row, message: e.message }
      end
    end

    {
      success: success,
      ignored: ignored,
      errors: errors
    }
  end

  def import_student_groups_from_csv(group_set, file)
    success = []
    errors = []
    ignored = []

    logger.info "Starting import of group for #{group_set.name} for #{code}"

    data = read_file_to_str(file)

    CSV.parse(data,
              headers: true,
              header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
              converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      next if row[0] =~ /^(group_name)|(name)/ # Skip header

      begin
        missing = missing_headers(row, %w(group_name username))
        if missing.count > 0
          errors << { row: row, message: "Missing headers: #{missing.join(', ')}" }
          next
        end

        # Get name from csv
        group_name = row['group_name'].strip unless row['group_name'].nil?

        # Find or create the group object
        grp = group_set.groups.find_by(name: group_name)

        if row['username'].nil?
          ignored << { row: row, message: "#{change}Skipping row with missing username" }
          next
        end

        username = row['username'].downcase.strip unless row['username'].nil?

        user = User.where(username: username).first

        if user.nil?
          errors << { row: row, message: "Unable to find user #{username}" }
          next
        end

        project = students.where('user_id = :id', id: user.id).first

        if project.nil?
          errors << { row: row, message: "Student #{username} is not enrolled in #{code}" }
          next
        end

        if group_set.keep_groups_in_same_class && !project.enrolled_in?(grp.tutorial)
          project.enrol_in(grp.tutorial)
        end

        grp.add_member(project)

        success << { row: row, message: "Added #{username} to #{grp.name}." }
      rescue Exception => e
        errors << { row: row, message: e.message }
      end
    end

    {
      success: success,
      ignored: ignored,
      errors: errors
    }
  end

  # Export all groups in the group set
  def export_groups_to_csv(group_set)
    CSV.generate do |row|
      row << %w(group_name capacity_adjustment tutorial campus)
      group_set.groups.each do |grp|
        row << [grp.name, grp.capacity_adjustment, grp.tutorial.abbreviation, grp.tutorial.campus.present? ? grp.tutorial.campus.abbreviation : '']
      end
    end
  end

  # Export all students in groups
  def export_student_groups_to_csv(group_set)
    CSV.generate do |row|
      row << %w(group_name username)
      group_set.groups.each do |grp|
        grp.projects.each do |project|
          row << [grp.name, project.student.username]
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

  def add_tutorial(day, time, location, tutor, campus, capacity, abbrev, tutorial_stream = nil)
    tutor_role = unit_roles.where('user_id=:user_id', user_id: tutor.id).first
    return nil if tutor_role.nil? || tutor_role.role == Role.student

    Tutorial.create!(unit_id: id, campus: campus, capacity: capacity, abbreviation: abbrev) do |tutorial|
      tutorial.meeting_day      = day
      tutorial.meeting_time     = time
      tutorial.meeting_location = location
      tutorial.unit_role_id     = tutor_role.id
      tutorial.tutorial_stream  = tutorial_stream unless tutorial_stream.nil?
    end
  end

  # First day of the week is sunday...
  def date_for_week_and_day(week, day)
    return nil if week.nil? || day.nil?

    if teaching_period.present?
      teaching_period.date_for_week_and_day(week, day)
    else
      day_num = Date::ABBR_DAYNAMES.index day.titlecase
      return nil if day_num.nil?

      start_day_num = start_date.wday

      start_date + week.weeks + (day_num - start_day_num).days
    end
  end

  def week_number(date)
    if teaching_period.present?
      teaching_period.week_number(date)
    else
      ((date - start_date) / 1.week).floor + 1
    end
  end

  def import_tasks_from_csv(file)
    success = []
    errors = []
    ignored = []

    data = read_file_to_str(file)

    CSV.parse(data,
              headers: true,
              header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip.tr(' ', '_').to_sym unless hdr.nil? }],
              converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
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
      errors: errors
    }
  end

  def task_definitions_csv
    TaskDefinition.to_csv(task_definitions)
  end

  def task_definitions_by_grade
    # Need to search as relation is already ordered
    TaskDefinition.where(unit_id: id).order('target_grade ASC, start_date ASC, abbreviation ASC')
  end

  def tutorial_stream_abbr
    tutorial_streams.map { |ts| ts.abbreviation }
  end

  def task_completion_csv
    task_def_by_grade = task_definitions_by_grade
    streams = tutorial_streams
    grp_sets = group_sets

    CSV.generate() do |csv|
      # Add header row
      csv << ([
        'Student ID',
        'Username',
        'Student Name',
        'Target Grade',
        'Email',
        'Portfolio',
        'Grade',
        'Rationale',
      ] +
             (streams.count > 0 ? streams.map { |t| t.abbreviation } : ['Tutorial']) +
             grp_sets.map(&:name) +
             task_def_by_grade.map do |task_definition|
               result = [task_definition.abbreviation]
               result << "#{task_definition.abbreviation} grade" if task_definition.is_graded?
               result << "#{task_definition.abbreviation} stars" if task_definition.has_stars?
               result << "#{task_definition.abbreviation} contribution" if task_definition.is_group_task?
               result
             end.flatten)

      # Add projects data
      # Get the details to fetch for each task definition...
      td_select = task_def_by_grade.map do |td|
        result = []
        result << "MAX(CASE WHEN tasks.task_definition_id = #{td.id} THEN (CASE WHEN task_statuses.name IS NULL THEN 'Not Started' ELSE task_statuses.name END) ELSE NULL END) AS status_#{td.id}"
        result << "MAX(CASE WHEN tasks.task_definition_id = #{td.id} THEN tasks.grade ELSE NULL END) AS grade_#{td.id}" if td.is_graded?
        result << "MAX(CASE WHEN tasks.task_definition_id = #{td.id} THEN tasks.quality_pts ELSE NULL END) AS stars_#{td.id}" if td.has_stars?
        result << "MAX(CASE WHEN tasks.task_definition_id = #{td.id} THEN tasks.contribution_pts ELSE NULL END) AS people_#{td.id}" if td.is_group_task?
        result
      end.flatten

      # Query across all projects, joined to task's via definitions to ensure all definitions are covered
      active_projects
        .joins(
          :unit,
          'INNER JOIN users ON projects.user_id = users.id',
          'INNER JOIN task_definitions ON task_definitions.unit_id = units.id',
          'LEFT OUTER JOIN tutorial_streams ON tutorial_streams.unit_id = units.id',
          'LEFT OUTER JOIN tutorial_enrolments ON tutorial_enrolments.project_id = projects.id',
          'LEFT OUTER JOIN tutorials ON tutorials.id = tutorial_enrolments.tutorial_id AND (tutorials.tutorial_stream_id = tutorial_streams.id OR tutorials.tutorial_stream_id IS NULL)',
          'LEFT OUTER JOIN tasks ON tasks.task_definition_id = task_definitions.id AND projects.id = tasks.project_id',
          'LEFT OUTER JOIN task_statuses ON tasks.task_status_id = task_statuses.id',
          'LEFT OUTER JOIN group_memberships ON group_memberships.project_id = projects.id AND group_memberships.active = TRUE',
          'LEFT OUTER JOIN groups ON groups.id = group_memberships.group_id'
        ).select(
          'projects.id as project_id', 'users.student_id as student_id', 'users.username as username', 'users.first_name as first_name',
          'users.last_name as last_name', 'projects.target_grade', 'users.email as email', 'compile_portfolio', 'portfolio_production_date', 'grade', 'grade_rationale',
          *td_select,
          # Get tutorial for each stream in unit
          *streams.map { |s| "MAX(CASE WHEN tutorials.tutorial_stream_id = #{s.id} OR tutorials.tutorial_stream_id IS NULL THEN tutorials.abbreviation ELSE NULL END) AS tutorial_#{s.id}" },
          # Get tutorial for case when no stream
          "MAX(CASE WHEN tutorial_streams.id IS NULL THEN tutorials.abbreviation ELSE NULL END) AS tutorial",
          *grp_sets.map { |gs| "MAX(CASE WHEN groups.group_set_id = #{gs.id} THEN groups.name ELSE NULL END) AS grp_#{gs.id}" }
        ).group(
          'projects.id', 'student_id', 'username', 'first_name', 'last_name', 'target_grade', 'email', 'compile_portfolio', 'portfolio_production_date', 'grade', 'grade_rationale'
        ).each do |row|
          csv << ([
            row['student_id'],
            row['username'],
            "#{row['first_name']} #{row['last_name']}",
            GradeHelper.grade_for(row['target_grade']),
            row['email'],
            row['portfolio_production_date'].present? && !row['compile_portfolio'] && File.exist?(FileHelper.student_portfolio_path(self, row['username'], true)),
            row['grade'] > 0 ? row['grade'] : nil,
            row['grade_rationale']
          ] + [1].map do
            if streams.empty?
              [row['tutorial']]
            else
              streams.map { |ts| row["tutorial_#{ts.id}"] }
            end
          end.flatten + grp_sets.map do |gs|
            row["grp_#{gs.id}"]
          end + task_def_by_grade.map do |td|
            result = [row["status_#{td.id}"].nil? ? TaskStatus.not_started.name : row["status_#{td.id}"]]
            result << GradeHelper.short_grade_for(row["grade_#{td.id}"]) if td.is_graded?
            result << row["stars_#{td.id}"] if td.has_stars?
            result << row["people_#{td.id}"] if td.is_group_task?
            result
          end.flatten)
        end
    end
  end

  #
  # Create a temp zip file with all student portfolios
  #
  def get_portfolio_zip(current_user)
    # Get a temp file path
    filename = FileHelper.sanitized_filename("portfolios-#{code}-#{current_user.username}")
    result = "#{FileHelper.tmp_file(filename)}.zip"

    return result if File.exist?(result)

    # Create a new zip
    Zip::File.open(result, Zip::File::CREATE) do |zip|
      active_projects.each do |project|
        # Skip if no portfolio at this time...
        next unless project.portfolio_available

        # Add file to zip in grade folder
        src_path = project.portfolio_path
        dst_path = FileHelper.sanitized_path(project.target_grade_desc.to_s, "#{project.student.username}-portfolio (#{project.tutors_and_tutorial})") + '.pdf'

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
    result = FileHelper.tmp_file("task-resources-#{code}.zip")

    return result if File.exist?(result)

    # Create a new zip
    Zip::File.open(result, Zip::File::CREATE) do |zip|
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
    result = FileHelper.tmp_file("submissions-#{code}-#{td.abbreviation}-#{current_user.username}-pdfs.zip")

    tasks_with_files = td.related_tasks_with_files

    return result if File.exist?(result)

    # Create a new zip
    Zip::File.open(result, Zip::File::CREATE) do |zip|
      Dir.mktmpdir do |dir|
        # Extract all of the files...
        tasks_with_files.each do |task|
          path_part = if td.is_group_task? && task.group
                        task.group.name.to_s
                      else
                        task.student.username.to_s
                      end

          FileUtils.cp task.portfolio_evidence_path, File.join(dir, path_part.to_s) + '.pdf'
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
    result = FileHelper.tmp_file("submissions-#{code}-#{td.abbreviation}-#{current_user.username}-files.zip")

    tasks_with_files = td.related_tasks_with_files

    return result if File.exist?(result)

    # Create a new zip
    Zip::File.open(result, Zip::File::CREATE) do |zip|
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

        type_data = check['type'].split
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

          type_data = check['type'].split
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
            url = moss.check(to_check, ->(line) { print '.' })
            puts()

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
        status: TaskStatus.id_to_key(t.status_id),
        completion_date: t.completion_date,
        submission_date: t.submission_date,
        times_assessed: t.times_assessed,
        grade: t.grade,
        quality_pts: t.quality_pts,
        num_new_comments: t.number_unread,
        similar_to_count: plagiarism_counts[t.task_id],
        pinned: t.pinned,
        has_extensions: t.has_extensions
      }
    end
  end

  def tutorial_enrolment_subquery
    tutorial_enrolments
      .joins(:tutorial)
      .select('tutorials.tutorial_stream_id as tutorial_stream_id', 'tutorials.id as tutorial_id', 'project_id').to_sql
  end

  #
  # Return all tasks from the database for this unit and given user
  #
  def get_all_tasks_for(user)
    student_tasks
      .joins(:task_status)
      .joins("LEFT OUTER JOIN (#{tutorial_enrolment_subquery}) as sq ON sq.project_id = projects.id AND (sq.tutorial_stream_id = task_definitions.tutorial_stream_id OR sq.tutorial_stream_id IS NULL)")
      .joins("LEFT JOIN task_comments ON task_comments.task_id = tasks.id AND (task_comments.type IS NULL OR task_comments.type <> 'TaskStatusComment')")
      .joins("LEFT JOIN comments_read_receipts crr ON crr.task_comment_id = task_comments.id AND crr.user_id = #{user.id}")
      .joins("LEFT JOIN task_pins ON task_pins.task_id = tasks.id AND task_pins.user_id = #{user.id}")
      .select(
        'sq.tutorial_id AS tutorial_id',
        'sq.tutorial_stream_id AS tutorial_stream_id',
        'tasks.id',
        "SUM(case when crr.user_id is null AND NOT task_comments.id is null then 1 else 0 end) as number_unread",
        'COUNT(distinct task_pins.task_id) != 0 as pinned',
        "SUM(case when task_comments.date_extension_assessed IS NULL AND task_comments.type = 'ExtensionComment' AND NOT task_comments.id IS NULL THEN 1 ELSE 0 END) > 0 as has_extensions",
        'project_id',
        'tasks.id as task_id',
        'task_definition_id',
        'task_definitions.start_date as start_date',
        'task_statuses.id as status_id',
        'completion_date',
        'times_assessed',
        'submission_date',
        'tasks.grade as grade',
        'quality_pts'
      )
      .group(
        'sq.tutorial_id',
        'sq.tutorial_stream_id',
        'task_statuses.id',
        'project_id',
        'tasks.id',
        'task_definition_id',
        'task_definitions.start_date',
        'status_id',
        'completion_date',
        'times_assessed',
        'submission_date',
        'grade',
        'quality_pts'
      )
  end

  #
  # Return the tasks that are waiting for feedback
  #
  def tasks_awaiting_feedback(user)
    get_all_tasks_for(user)
      .where('task_statuses.id IN (:ids)', ids: [TaskStatus.discuss, TaskStatus.redo, TaskStatus.demonstrate, TaskStatus.fix_and_resubmit])
      .order('task_definition_id')
  end

  #
  # Return the tasks that should be listed under a tutor's task inbox.
  #
  # Thses tasks are:
  #   - those that have the ready for feedback (rff) state, or
  #   - where new student comments are > 0
  #
  # They are sorted by a task's "action_date". This defines the last
  # time a task has been "actioned", either the submission date or latest
  # student comment -- whichever is newer.
  #
  def tasks_for_task_inbox(user)
    get_all_tasks_for(user)
      .having('task_statuses.id IN (:ids) OR COUNT(task_pins.task_id) > 0 OR SUM(case when crr.user_id is null AND NOT task_comments.id is null then 1 else 0 end) > 0', ids: [TaskStatus.ready_for_feedback, TaskStatus.need_help])
      .order('pinned DESC, submission_date ASC, MAX(task_comments.created_at) ASC, task_definition_id ASC')
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
           .joins('LEFT OUTER JOIN tutorial_enrolments ON tutorial_enrolments.project_id = projects.id')
           .joins('LEFT OUTER JOIN tutorials ON tutorials.id = tutorial_enrolments.tutorial_id AND (tutorials.tutorial_stream_id = task_definitions.tutorial_stream_id OR tutorials.tutorial_stream_id IS NULL)')
           .select('tutorials.tutorial_stream_id AS stream_id', 'tutorial_enrolments.tutorial_id AS tutorial_id', 'task_definition_id', 'task_statuses.id as status_id', 'COUNT(tasks.id) as num_tasks')
           .where('task_status_id > 1')
           .group('stream_id', 'tutorial_id', 'tasks.task_definition_id', 'status_id')
           .map do |r|
      {
        tutorial_stream_id: r.stream_id,
        tutorial_id: r.tutorial_id,
        task_definition_id: r.task_definition_id,
        status: TaskStatus.id_to_key(r.status_id),
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
          tutorial_stream_id: t.tutorial_stream_id,
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
        result[e[:task_definition_id]][e[:tutorial_id]] = []
      end

      result[e[:task_definition_id]][e[:tutorial_id]] << { tutorial_stream_id: e[:tutorial_stream_id], status: e[:status], num: e[:num] }
    end

    result
  end

  #
  # Returns an array of { tutorial_id: id, grade: g, num: n } -- showing the number of students
  # aiming for a grade in this indicated unit.
  #
  def student_target_grade_stats
    data = active_projects
           .joins('LEFT OUTER JOIN tutorial_enrolments ON tutorial_enrolments.project_id = projects.id')
           .joins('LEFT OUTER JOIN tutorials ON tutorials.id = tutorial_enrolments.tutorial_id')
           .select('tutorials.tutorial_stream_id as tutorial_stream_id, tutorial_enrolments.tutorial_id as tutorial_id, projects.target_grade, COUNT(projects.id) as num').group('tutorial_enrolments.tutorial_id, tutorials.tutorial_stream_id, projects.target_grade')
           .order('tutorial_enrolments.tutorial_id, projects.target_grade')
           .map { |r| { tutorial_id: r.tutorial_id, tutorial_stream_id: r.tutorial_stream_id, grade: r.target_grade, num: r.num } }
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
           .joins('LEFT OUTER JOIN tutorial_enrolments ON tutorial_enrolments.project_id = tasks.project_id')
           .joins('LEFT OUTER JOIN tutorials ON tutorials.id = tutorial_enrolments.tutorial_id AND (tutorials.tutorial_stream_id = task_definitions.tutorial_stream_id OR tutorials.tutorial_stream_id IS NULL)')
           .select('tutorials.tutorial_stream_id as tutorial_stream_id', 'tutorial_enrolments.tutorial_id as tutorial_id', 'projects.target_grade as target_grade', 'tasks.project_id', 'Count(tasks.id) as num')
           .where('task_status_id = :complete', complete: TaskStatus.complete.id)
           .group('tutorial_enrolments.tutorial_id', 'tutorials.tutorial_stream_id', 'projects.target_grade', 'tasks.project_id')
           .order('tutorial_enrolments.tutorial_id')
    data.map { |r| { tutorial_id: r.tutorial_id, tutorial_stream_id: r.tutorial_stream_id, grade: r.target_grade, project: r.project_id, num: r.num } }
  end

  def _calculate_task_completion_stats(data)
    values = data.map { |r| r[:num] }

    if values && !values.empty?
      values.sort!

      median_value = if values.length.even?
                       ((values[values.length / 2] + values[(values.length / 2) - 1]) / 2.0).round(1)
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

    result = {}
    result[:unit] = _calculate_task_completion_stats(data)
    result[:tutorial] = {}
    result[:grade] = {}

    tutorials.each do |t|
      result[:tutorial][t.id] = _calculate_task_completion_stats(data.select { |r| r[:tutorial_id] == t.id })
    end

    for i in GradeHelper::RANGE do
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
           .joins('LEFT OUTER JOIN tutorial_enrolments ON tutorial_enrolments.project_id = projects.id')
           .joins('LEFT OUTER JOIN tutorials ON tutorials.id = tutorial_enrolments.tutorial_id AND (tutorials.tutorial_stream_id = task_definitions.tutorial_stream_id OR tutorials.tutorial_stream_id IS NULL)')
           .select('tutorials.tutorial_stream_id as tutorial_stream_id, tutorial_enrolments.tutorial_id as tutorial_id, projects.id as project_id, task_statuses.id as status_id, task_definitions.target_grade, learning_outcome_task_links.learning_outcome_id, learning_outcome_task_links.rating, COUNT(tasks.id) as num')
           .where('projects.enrolled = TRUE AND learning_outcome_task_links.task_id is NULL')
           .group('tutorial_enrolments.tutorial_id, tutorials.tutorial_stream_id, projects.id, task_statuses.id, task_definitions.target_grade, learning_outcome_task_links.learning_outcome_id, learning_outcome_task_links.rating')
           .order('tutorial_enrolments.tutorial_id, projects.id')
           .map do |r|
      {
        project_id: r.project_id,
        tutorial_id: r.tutorial_id,
        tutorial_stream_id: r.tutorial_stream_id,
        learning_outcome_id: r.learning_outcome_id,
        rating: r.rating,
        grade: r.target_grade,
        status: TaskStatus.id_to_key(r.status_id),
        num: r.num
      }
    end

    grade_weight = { 0 => 1, 1 => 2, 2 => 4, 3 => 8 }
    status_weight = {
      not_started: 0.0,
      fail: 0.0,
      working_on_it: 0.0,
      need_help: 0.0,
      redo: 0.1,
      feedback_exceeded: 0.1,
      fix_and_resubmit: 0.3,
      time_exceeded: 0.5,
      ready_for_feedback: 0.7,
      discuss: 0.8,
      demonstrate: 0.8,
      complete: 1.0
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
                                                   (e[:rating] * status_weight[e[:status]] * grade_weight[e[:grade]] * e[:num])
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
                         ((values[values.length / 2] + values[(values.length / 2) - 1]) / 2.0).round(1)
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
  def tutor_assessment_csv
    CSV.generate() do |csv|
      csv << [
        'Username',
        'Tutor Name',
        'Total Tasks Assessed'
      ]

      tasks
        .joins(project: [{ tutorial_enrolments: { tutorial: { unit_role: :user } } }])
        .select('users.username', 'users.first_name', 'users.last_name', 'SUM(times_assessed) AS total')
        .group('users.username', 'users.first_name', 'users.last_name')
        .each do |r|
          csv << [r.username, "#{r.first_name} #{r.last_name}", r.total]
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

    output_zip = FileHelper.tmp_file("batch_ready_for_feedback_#{code}_#{user.username}.zip")

    return result if File.exist?(output_zip)

    # Create a new zip
    Zip::File.open(output_zip, Zip::File::CREATE) do |zip|
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
                     'rff'
                   end

        csv_str << "\n#{student.username.tr(',', '_')},#{student.name.tr(',', '_')},#{task.project.tutorial_for(task.task_definition).abbreviation},#{task.task_definition.abbreviation.tr(',', '_')},\"#{task.last_comment_by(task.project.student).gsub(/"/, '""')}\",\"#{task.last_comment_by(user).gsub(/"/, '""')}\",#{mark_col},,,#{task.task_definition.max_quality_pts},"

        src_path = task.portfolio_evidence_path

        next if src_path.nil? || src_path.empty?
        next unless File.exist? src_path

        # make dst path of "<student id>/<task abbrev>.pdf"
        dst_path = FileHelper.sanitized_path(task.project.student.username.to_s, "#{task.task_definition.abbreviation}-#{task.id}") + '.pdf'
        # now copy it over
        zip.add(dst_path, src_path)
      end

      # Add group tasks...
      tasks.select(&:group_submission).group_by(&:group_submission).each do |subm, tasks|
        task = tasks.first
        # Skip tasks that do not yet have a PDF generated
        next if task.processing_pdf?

        # Add to the template entry string
        grp = task.group
        next if grp.nil?

        csv_str << "\nGRP_#{grp.id}_#{subm.id},#{grp.name.tr(',', '_')},#{grp.tutorial.abbreviation},#{task.task_definition.abbreviation.tr(',', '_')},\"#{task.last_comment_not_by(user).gsub(/"/, '""')}\",\"#{task.last_comment_by(user).gsub(/"/, '""')}\",rff,,#{task.task_definition.max_quality_pts},"

        src_path = task.portfolio_evidence_path

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

        related_tasks = [task]
        owner_text = project.user.name
      end

      unless AuthorisationHelpers.authorise? user, task, :put
        errors << { row: task_entry, error: 'You do not have permission to assess this task.' }
        next
      end

      begin
        task.trigger_transition(trigger: task_entry['status'], by_user: user, quality: task_entry['new quality'].to_i) # saves task
        task.grade_task(task_entry['new grade']) # try to grade task if need be

        if task_entry['new comment'].nil? || task_entry['new comment'].empty?
          success << { row: task_entry, message: "Updated task #{task.task_definition.abbreviation} for #{owner_text}" }
        else
          task.add_text_comment user, task_entry['new comment']
          success << { row: task_entry, message: "Updated task #{task.task_definition.abbreviation} for #{owner_text}" }
          success << { row: {}, message: "Added comment to #{task.task_definition.abbreviation} for #{owner_text}" }
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

    type = mime_type(file["tempfile"].path)

    # check mime is correct before uploading
    accept = ['text/', 'text/plain', 'text/csv', 'application/zip', 'multipart/x-gzip', 'multipart/x-zip', 'application/x-gzip', 'application/octet-stream']
    unless mime_in_list?(file["tempfile"].path, accept)
      errors << { row: {}, message: "File given is not a zip or csv file - detected #{type}" }
      return {
        success: success,
        ignored: ignored,
        errors: errors
      }
    end

    if type.start_with?('text/', 'text/plain', 'text/csv')
      update_task_status_from_csv(user, File.read(file["tempfile"].path), success, ignored, errors)
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

      Zip::File.open(file["tempfile"].path) do |zip|
        # Find the marking file within the directory tree
        marking_file = zip.glob('**/marks.csv').first

        # No marking file found
        if marking_file.nil?
          errors << { row: {}, message: 'No marks.csv contained in zip.' }
          return {
            success: success,
            ignored: ignored,
            errors: errors
          }
        end

        # Read the csv
        csv_str = marking_file.get_input_stream.read
        csv_str.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless csv_str.nil?

        # Update tasks and email students
        unless update_task_status_from_csv(user, csv_str, success, ignored, errors)
          errors << { row: {}, message: 'Aborting import as mark.csv was not processed successfully.' }
          return {
            success: success,
            ignored: ignored,
            errors: errors
          }
        end

        # read keys from CSV - to check that files exist in csv
        entry_data = CSV.parse(csv_str, headers: true,
                                        header_converters: [->(i) { i.nil? ? '' : i }, :downcase],
                                        converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }])

        # Copy over the updated/marked files to the file system
        zip.each do |file|
          # Skip processing marking file
          next if File.basename(file[:name]) == 'marks.csv' || File.basename(file[:name]) == 'readme.txt'

          # Test filename pattern
          if (/.*-\d+.pdf/i =~ File.basename(file[:name])) != 0
            if file[:name][-1] != '/'
              ignored << { row: "File #{file[:name]}", message: 'Does not appear to be a task PDF.' }
            end
            next
          end
          if (/\._.*/ =~ File.basename(file[:name])) == 0
            ignored << { row: "File #{file[:name]}", message: 'Does not appear to be a task PDF.' }
            next
          end

          # Extract the id from the filename
          task_id_from_filename = File.basename(file[:name], '.pdf').split('-').last
          task = Task.find_by(id: task_id_from_filename)
          if task.nil?
            ignored << { row: "File #{file[:name]}", message: 'Unable to find associated task.' }
            next
          end

          # Ensure that this task's id is inside entry_data
          task_entry = entry_data.select { |t| t['task'] == task.task_definition.abbreviation.tr(',', '_') && t['username'] == task.project.user.username }.first
          if task_entry.nil?
            # error!({"error" => "File #{file[:name]} has a mismatch of task id ##{task.id} (this task id does not exist in marks.csv)"}, 403)
            errors << { row: "File #{file[:name]}", message: "Task id #{task.id} not in marks.csv" }
            next
          end

          if task.unit != self
            errors << { row: "File #{file[:name]}", message: 'This task does not relate to this unit.' }
            next
          end

          # Can the user assess this task?
          unless AuthorisationHelpers.authorise? user, task, :put
            errors << { row: "File #{file[:name]}", error: "You do not have permission to assess task with id #{task.id}" }
            next
          end

          # Read into the task's portfolio_evidence path the new file
          tmp_file = File.join(tmp_dir, File.basename(file[:name]))
          task.portfolio_evidence_path = task.final_pdf_path

          # get file out of zip... to tmp_file
          file.extract(tmp_file) { true }

          # copy tmp_file to dest
          if FileHelper.copy_pdf(tmp_file, task.portfolio_evidence_path)
            if task.group.nil?
              success << { row: "File #{file[:name]}", message: "Replace PDF of task #{task.task_definition.abbreviation} for #{task.student.name}" }
            else
              success << { row: "File #{file[:name]}", message: "Replace PDF of group task #{task.task_definition.abbreviation} for #{task.group.name}" }
            end
            FileUtils.rm tmp_file
          else
            errors << { row: "File #{file[:name]}", message: 'The file does not appear to be a valid PDF.' }
            next
          end
        end
      end

      # Remove the extract dir
      FileUtils.rm_rf tmp_dir
    end

    {
      success: success,
      ignored: ignored,
      errors: errors
    }
  end

  def send_weekly_status_emails(summary_stats)
    return unless send_notifications

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
      project.send_weekly_status_email(summary_stats, days_from_start_of_unit > 28 && days_to_end_of_unit > 14)
    end

    summary_stats[:num_students_without_tutors] = active_projects.joins('LEFT OUTER JOIN tutorial_enrolments on tutorial_enrolments.project_id = projects.id').where('tutorial_enrolments.tutorial_id' => nil).count

    staff.each do |ur|
      ur.populate_summary_stats(summary_stats)
    end

    staff.each do |ur|
      ur.send_weekly_status_email(summary_stats)
    end

    summary_stats[:staff] = {}
  end

  private

  def delete_associated_files
    FileUtils.rm_rf FileHelper.unit_dir(self)
    FileUtils.rm_rf FileHelper.unit_portfolio_dir(self)
    FileUtils.cd FileHelper.student_work_dir
  end

  def propogate_date_changes_to_tasks
    return unless saved_change_to_start_date?

    # Get the time from the old start date to the new start date.
    # using... new - old ... if moved forward in time new > old
    # so diff is positive and added to each task definition moves task definitions forward
    date_diff = saved_change_to_start_date[1] - saved_change_to_start_date[0]

    task_definitions.each do |td|
      td.propogate_date_changes date_diff
    end
  end
end
