require 'csv'
require 'bcrypt'
require 'json'

class Unit < ActiveRecord::Base
  include ApplicationHelper

  def self.permissions
    { 
      :Student  => [ :get_unit ],
      :Tutor    => [ :get_unit, :get_students, :enrol_student, :get_ready_to_mark_submissions],
      :Convenor => [ :get_unit, :get_students, :enrol_student, :uploadCSV, :downloadCSV, :update, :employ_staff, :add_tutorial, :add_task_def, :get_ready_to_mark_submissions, :change_project_enrolment ],
      :nil      => []
    }
  end

  def role_for(user)
    if convenors.where('unit_roles.user_id=:id', id: user.id).count == 1
      Role.convenor
    elsif tutors.where('unit_roles.user_id=:id', id: user.id).count == 1
      Role.tutor
    elsif students.where('unit_roles.user_id=:id', id: user.id).count == 1
      Role.student
    else
      nil
    end
  end

  validates_presence_of :name, :description, :start_date, :end_date

  # Model associations.
  # When a Unit is destroyed, any TaskDefinitions, Tutorials, and ProjectConvenor instances will also be destroyed.
  has_many :task_definitions, -> { order "target_date ASC, abbreviation ASC" }, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :tutorials, dependent: :destroy
  has_many :unit_roles, dependent: :destroy
  has_many :tasks, through: :projects
  
  has_many :convenors, -> { joins(:role).where("roles.name = :role", role: 'Convenor') }, class_name: 'UnitRole'
  has_many :staff, ->     { joins(:role).where("roles.name = :role_convenor or roles.name = :role_tutor", role_convenor: 'Convenor', role_tutor: 'Tutor') }, class_name: 'UnitRole' 

  scope :current,               ->{ current_for_date(Time.zone.now) }
  scope :current_for_date,      ->(date) { where("start_date <= ? AND end_date >= ?", date, date) }
  scope :not_current,           ->{ not_current_for_date(Time.zone.now) }
  scope :not_current_for_date,  ->(date) { where("start_date > ? OR end_date < ?", date, date) }
  scope :set_active,            ->{ where("active = ?", true) }
  scope :set_inactive,          ->{ where("active = ?", false) }

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
    Project.joins(:unit_role).where('unit_roles.role_id = 1 and projects.unit_id=:unit_id', unit_id: id)
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
  def enrol_student(user_id, tutorial_id=nil)
    # Validates that a student is not already assigned to the unit
    existing_role = unit_roles.where("user_id=:user_id", user_id: user_id).first
    if not existing_role.nil?
      return existing_role.project
    end

    # Validates that the tutorial exists for the unit
    if (not tutorial_id.nil?) && tutorials.where("id=:id", id: tutorial_id).count == 0
      return nil
    end

    # Put the user in the appropriate tutorial (ie. create a new unit_role)
    unit_role = UnitRole.create!(
      user_id: user_id,
      #tutorial_id: tutorial_id,
      unit_id: self.id,
      role_id: Role.where(name: 'Student').first.id
    )

    unit_role.tutorial_id = tutorial_id unless tutorial_id.nil?

    unit_role.save!

    project = Project.create!(
      unit_role_id: unit_role.id,
      unit_id: self.id,
      task_stats: "1.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0|1.0"
    )

    # Create task instances for the project
    task_definitions_for_project = TaskDefinition.where(unit_id: self.id)

    task_definitions_for_project.each do |task_definition|
      Task.create(
        task_definition_id: task_definition.id,
        project_id: project.id,
        task_status_id: 1,
        awaiting_signoff: false
      )
    end

    project
  end

  # Removes a user (and their tasks etc.) from this project
  def remove_user(user_id)
    unit_roles = UnitRole.joins(project: :unit).where(user_id: user_id, projects: {unit_id: self.id})

    unit_roles.each do |unit_role|
      unit_role.destroy
    end
  end

  def change_convenors(convenor_ids)
    convenor_role = Role.convenor

    # Replace the current list of convenors for this project with the new list selected by the user
    unit_convenors        = UnitRole.where(unit_id: self.id, role_id: convenor_role.id)
    removed_convenor_ids  = unit_convenors.map(&:user).map(&:id) - convenor_ids

    # Delete any convenors that have been removed
    UnitRole.where(unit_id: self.id, role_id: convenor_role.id, user_id: removed_convenor_ids).destroy_all

    # Find or create convenors
    convenor_ids.each do |convenor_id|
      new_convenor = UnitRole.find_or_create_by_unit_id_and_user_id_and_role_id(unit_id: self.id, user_id: convenor_id, role_id: convenor_role.id)
      new_convenor.save!
    end
  end

  # Imports users into a project from CSV file.
  # Format: Student ID,Course ID,First Name,Initials,Surname,Mark,Assessment,Status
  # Only Student ID, First Name, and Surname are used.
  def import_users_from_csv(file)
    tutorial_cache = {}
    added_users = []
    
    CSV.foreach(file) do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /subject_code/
      # next if row[5] !~ /^LA\d/

      subject_code, username  = row[0..1]
      first_name, last_name   = [row[2], row[3]].map{|name| name.titleize }
      email, tutorial_code    = row[4..5]

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
        user_not_in_project = UnitRole.joins(project: :unit).where(
          user_id: project_participant.id,
          projects: {unit_id: id}
        ).count == 0

        tutorial = tutorial_cache[tutorial_code] || Tutorial.where(abbreviation: tutorial_code, unit_id: id).first
        tutorial_cache[tutorial_code] ||= tutorial

        # Add the user to the project (if not already in there)
        if user_not_in_project
          added_users << project_participant
          if not tutorial.nil?
            enrol_student(project_participant.id, tutorial.id)
          else
            enrol_student(project_participant.id)
          end
        else
          # update tutorial
          unit_role = UnitRole.joins(project: :unit).where(
            user_id: project_participant.id,
            projects: {unit_id: id}
          ).first

          if unit_role.tutorial_id != tutorial.id
            unit_role = UnitRole.find(unit_role.id)
            unit_role.tutorial = tutorial
            unit_role.save
            added_users << project_participant #TODO: would be good to separate into added/updated
          end
        end
      end
    end
    added_users
  end

  # Use the values in the CSV to set the enrolment of these
  # students to false for this unit.
  # CSV should contain just the usernames to withdraw
  def unenrol_users_from_csv(file)
    # puts 'starting withdraw'
    changed_projects = []
    
    CSV.foreach(file) do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /username/
      # next if row[5] !~ /^LA\d/

      username  = row[0].downcase

      # puts username

      project_participant = User.where(username: username)

      next if not project_participant
      next if not project_participant.count == 1
      project_participant = project_participant.first

      user_project = UnitRole.joins(project: :unit).where(
          user_id: project_participant.id,
          projects: {unit_id: id}
        )

      next if not user_project
      next if not user_project.count == 1

      user_project = user_project.first.project

      user_project.enrolled = false
      user_project.save
      changed_projects << username
    end

    changed_projects # return the changed projects
  end 

  def export_users_to_csv
    CSV.generate do |row|
      row << ["subject_code", "username", "first_name", "last_name", "email", "tutorial"]
      students.each do |project|
        row << [project.unit.code, project.student.username,  project.student.first_name, project.student.last_name, project.student.email, project.tutorial_abbr]
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
    
    Tutorial.find_or_create_by( { unit_id: id, abbreviation: abbrev } ) do |tutorial|
      tutorial.meeting_day      = day
      tutorial.meeting_time     = time
      tutorial.meeting_location = location
      tutorial.unit_role_id     = tutor_role.id
    end
  end

  def add_new_task_def(task_def, project_cache=nil)
    project_cache = Project.where(unit_id: id) if project_cache.nil?
    project_cache.each do |project|
      Task.create(
        task_definition_id: task_def.id,
        project_id:         project.id,
        task_status_id:     1,
        awaiting_signoff:   false,
        completion_date:    nil
      )
    end
  end

  def import_tasks_from_csv(file)
    added_tasks = []
    project_cache = Project.where(unit_id: id)

    CSV.foreach(file) do |row|
      next if row[0] =~ /^(Task Name)|(name)/ # Skip header

      name, abbreviation, description, weighting, required, target_grade, upload_requirements, target_date = row[0..7]
      next if name.nil? || abbreviation.nil?

      description = "(No description given)" if description == "NULL"
      target_date = target_date.strip
      
      if target_date !~ /20\d\d\-\d{1,2}\-\d{1,2}$/ # Matches YYYY-mm-dd by default
        if target_date =~ /\d{1,2}\-\d{1,2}\-20\d\d/ # Matches dd-mm-YYYY
          target_date = target_date.split("-").reverse.join("-")
        elsif target_date =~ /\d{1,2}\/\d{1,2}\/20\d\d$/ # Matches dd/mm/YYYY
          target_date = target_date.split("/").reverse.join("-")
        elsif target_date =~ /\d{1,2}\/\d{1,2}\/\d\d$/ # Matches dd/mm/YY
          target_date = target_date.split("/").reverse.join("-")
        elsif target_date =~ /\d{1,2}\-\d{1,2}\-\d\d$/ # Matches dd-mm-YY
          target_date = target_date.split("-").reverse.join("-")
        elsif target_date =~ /\d{1,2}\-\d{1,2}\-\d\d \d\d:\d\d:\d\d$/ # Matches dd-mm-YY
          target_date = target_date.split(" ").first
        elsif target_date =~ /\d{1,2}\/\d{1,2}\/\d\d [\d:]+$/ # Matches dd/mm/YY 00:00:00
          target_date = target_date.split(" ").first.split("/").reverse.join("-")
        end
      end

      new_task = TaskDefinition.find_by(unit_id: id, abbreviation: abbreviation).nil? && TaskDefinition.find_by(unit_id: id, name: name).nil?

      if new_task
        # TODO: Should background/task queue this work
        task_definition = TaskDefinition.find_or_create_by(unit_id: id, name: name, abbreviation: abbreviation) do |task_definition|
          task_definition.name                        = name
          task_definition.unit_id                     = id
          task_definition.abbreviation                = abbreviation
          task_definition.description                 = description
          task_definition.weighting                   = BigDecimal.new(weighting)
          task_definition.required                    = ["Yes", "y", "Y", "yes", "true", "TRUE", "1"].include? required
          task_definition.target_grade                = target_grade
          task_definition.target_date                 = Time.zone.parse(target_date)
          task_definition.upload_requirements         = upload_requirements
        end
        
        if task_definition.persisted?
          added_tasks.push(task_definition)

          add_new_task_def task_definition, project_cache
        end
      end
    end
    added_tasks
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
      ] + task_definitions.map{|task_definition| task_definition.abbreviation }
      active_projects.each do |project|
        csv << project.task_completion_csv
      end
    end
  end

  def status_distribution
    Project.status_distribution(projects)
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
end
