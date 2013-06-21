require 'csv'
require 'bcrypt'

class Unit < ActiveRecord::Base
  include ApplicationHelper

  attr_accessible :code, :description, :end_date, :name, :start_date, :active
  validates_presence_of :name, :description, :start_date, :end_date

  # Accessor to allow setting of convenors via the new/edit form
  attr_accessor :convenors  

  # Model associations. 
  # When a Unit is destroyed, any TaskDefinitions, Tutorials, and ProjectConvenor instances will also be destroyed.
  has_many :task_definitions, dependent: :destroy	  			
  has_many :projects, dependent: :destroy					 
  has_many :tutorials, dependent: :destroy

  scope :convened_by, lambda {|convenor_user|
    where(project_convenors: {user_id: convenor_user.id})
  }

  scope :current, lambda {
    current_for_date(Time.zone.now)
  }

  scope :current_for_date, lambda {|date|
    where("start_date <= ? AND end_date >= ?", date, date)
  }

  scope :not_current, lambda {
    not_current_for_date(Time.zone.now)
  }

  scope :not_current_for_date, lambda {|date|
    where("start_date > ? OR end_date < ?", date, date)
  }

  scope :set_active, lambda {
    where("active = ?", true)
  }

  scope :set_inactive, lambda {
    where("active = ?", false)
  }
  
  # Adds a user to this project.
  def add_user(user_id, tutorial_id, project_role)
    # Put the user in the appropriate tutorial (ie. create a new unit_role)
    unit_role = UnitRole.new(
      user_id: user_id,
      tutorial_id: tutorial_id
    )

    project = unit_role.build_project(
      started: false,
      unit: self,
      project_role: project_role
    )
    project.save

    # Associate the tutorial membership with the project that was created
    unit_role.project_id = project.id
    unit_role.save

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

  end

  # Removes a user (and their tasks etc.) from this project
  def remove_user(user_id)
    unit_roles = UnitRole.joins(project: :unit).where(user_id: user_id, projects: {unit_id: self.id})

    unit_roles.each do |unit_role|
      unit_role.destroy
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

  def status_distribution
    projects = Project.where(unit_id: id)
    project_count = projects.length
    
    status_totals = {
      ahead: 0,
      on_track: 0,
      behind: 0,
      danger: 0,
      doomed: 0,
      not_started: 0,
      total: 0
    }

    projects.each do |project|
      if project.started?
        status_totals[project.progress] += 1
      else
        status_totals[:not_started] += 1
      end
    end

    status_totals[:total] = project_count
    Hash[status_totals.sort_by{ |status, count| count }.reverse]
  end
end
