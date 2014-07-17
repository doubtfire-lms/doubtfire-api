require 'csv'
require 'bcrypt'

class Unit < ActiveRecord::Base
  include ApplicationHelper

  def self.permissions
    { 
      student: [],
      tutor: [ :get_students ],
      nil => []
    }
  end

  def role_for(user)
    if convenors.where('users.id=:id', id: user.id).count >= 1
      :convenor
    elsif tutors.where('users.id=:id', id: user.id).count >= 1
      :tutor
    elsif students.where('unit_roles.user_id=:id', id: user.id).count == 1
      :student
    else
      nil
    end
  end

  validates_presence_of :name, :description, :start_date, :end_date

  # Model associations.
  # When a Unit is destroyed, any TaskDefinitions, Tutorials, and ProjectConvenor instances will also be destroyed.
  has_many :task_definitions, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :tutorials, dependent: :destroy
  has_many :unit_roles, dependent: :destroy
  has_many :convenors, -> { joins(:role).where("roles.name = :role", role: 'Convenor') }, class_name: 'UnitRole'

  scope :current,               ->{ current_for_date(Time.zone.now) }
  scope :current_for_date,      ->(date) { where("start_date <= ? AND end_date >= ?", date, date) }
  scope :not_current,           ->{ not_current_for_date(Time.zone.now) }
  scope :not_current_for_date,  ->(date) { where("start_date > ? OR end_date < ?", date, date) }
  scope :set_active,            ->{ where("active = ?", true) }
  scope :set_inactive,          ->{ where("active = ?", false) }

  def self.for_user(user)
    # TODO: Revise this
    if user.admin?
      Unit.all
    else
      Unit.joins(:unit_roles).where('unit_roles.user_id = :user_id', user_id: user.id)
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

  # Adds a user to this project.
  def add_user(user_id, tutorial_id, project_role)
    # Put the user in the appropriate tutorial (ie. create a new unit_role)
    unit_role = UnitRole.create!(
      user_id: user_id,
      tutorial_id: tutorial_id,
      unit_id: self.id,
      role_id: Role.where(name: 'Student').first.id
    )

    project = Project.create!(
      unit_role_id: unit_role.id,
      unit_id: self.id,
      task_stats: "1.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0|0.0"
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
    convenor_role = Role.where(name: 'Convenor').first

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

    CSV.foreach(file) do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /Subject Code/
      next if row[5] !~ /^LA\d/

      subject_code, username  = row[0..1]
      first_name, last_name   = [row[2], row[3]].map{|name| name.titleize }
      email, class_id         = row[4..5]

      project_participant = User.find_or_create_by_username(username: username) {|new_user|
        new_user.username           = username
        new_user.first_name         = first_name
        new_user.last_name          = last_name
        new_user.email              = email
        new_user.nickname           = first_name
        new_user.encrypted_password = BCrypt::Password.create("password")
        new_user.system_role        = "user"
      }

      project_participant.save!(validate: false) unless project_participant.persisted?

      user_not_in_project = UnitRole.joins(project: :unit).where(
        user_id: project_participant.id,
        projects: {unit_id: id}
      ).count == 0

      tutorial = tutorial_cache[class_id] || Tutorial.where(code: class_id, unit_id: id).first
      tutorial_cache[class_id] ||= tutorial

      # Add the user to the project (if not already in there)
      if user_not_in_project
        add_user(project_participant.id, tutorial.id, "student")
      end
    end
  end

  def import_tutorials_from_csv(file)
    CSV.foreach(file) do |row|
      next if row[0] =~ /Subject Code/ # Skip header

      class_type, class_id, day, time, location, tutor_username = row[2..-1]
      next if class_type !~ /Lab/

      Tutorial.find_or_create_by_unit_id_and_code(id, class_id) do |tutorial|
        tutorial.meeting_day      = day
        tutorial.meeting_time     = time
        tutorial.meeting_location = location

        user_for_tutor = User.where(username: tutor_username).first
        tutorial.user_id          = user_for_tutor.id
      end
    end
  end

  def import_tasks_from_csv(file)
    project_cache = nil

    CSV.foreach(file) do |row|
      next if row[0] =~ /^(Task Name)|(name)/ # Skip header

      name, abbreviation, description, weighting, required, target_date = row[0..6]
      description = "(No description given)" if description == "NULL"

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

      # TODO: Should background/task queue this work
      task_definition = TaskDefinition.find_or_create_by_unit_id_and_name(id, name) do |task_definition|
        task_definition.name                        = name
        task_definition.unit_id         = id
        task_definition.abbreviation                = abbreviation
        task_definition.description                 = description
        task_definition.weighting                   = BigDecimal.new(weighting)
        task_definition.required                    = ["Yes", "y", "Y", "yes", "true", "TRUE", "1"].include? required
        task_definition.target_date                 = Time.zone.parse(target_date)
      end

      task_definition.save! unless task_definition.persisted?

      project_cache ||= Project.where(unit_id: id)

      project_cache.each do |project|
        Task.create(
          task_definition_id: task_definition.id,
          project_id:       project.id,
          task_status_id:   1,
          awaiting_signoff: false,
          completion_date:  nil
        )
      end
    end
  end

  def task_definitions_csv
    TaskDefinition.to_csv(task_definitions)
  end

  def task_completion_csv(options={})
    CSV.generate(options) do |csv|
      csv << [
        'Student ID',
        'Student Name',
        'Tutor Name',
      ] + task_definitions.map{|task_definition| task_definition.name }
      projects.each do |project|
        csv << project.task_completion_csv
      end
    end
  end

  def status_distribution
    Project.status_distribution(projects)
  end
end
