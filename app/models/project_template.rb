require 'csv'
require 'bcrypt'

class ProjectTemplate < ActiveRecord::Base
  include ApplicationHelper

  attr_accessible :official_name, :description, :end_date, :name, :start_date, :active
  validates_presence_of :name, :description, :start_date, :end_date

  # Accessor to allow setting of convenors via the new/edit form
  attr_accessor :convenors  

  # Model associations. 
  # When a ProjectTemplate is destroyed, any TaskTemplates, Teams, and ProjectConvenor instances will also be destroyed.
  has_many :task_templates, :dependent => :destroy	  			
  has_many :projects, :dependent => :destroy					 
  has_many :teams, :dependent => :destroy
  has_many :project_convenors, :dependent => :destroy

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
  
  # Adds a user to this project.
  def add_user(user_id, team_id, project_role)
    # Put the user in the appropriate team (ie. create a new team_membership)
    team_membership = TeamMembership.new(
      user_id: user_id,
      team_id: team_id
    )

    project = team_membership.build_project(
      started: false,
      project_template: self,
      project_role: project_role
    )
    project.save

    # Associate the team membership with the project that was created
    team_membership.project_id = project.id
    team_membership.save

    # Create task instances for the project
    task_templates_for_project = TaskTemplate.where(:project_template_id => self.id)

    task_templates_for_project.each do |task_template|
      Task.create(
        task_template_id: task_template.id,
        project_id: project.id,
        task_status_id: 1,
        awaiting_signoff: false
      )
    end

  end

  # Removes a user (and their tasks etc.) from this project
  def remove_user(user_id)
    team_memberships = TeamMembership.joins(:project => :project_template).where(:user_id => user_id, :projects => {:project_template_id => self.id})

    team_memberships.each do |team_membership|
      team_membership.destroy
    end
  end

  # Imports users into a project from CSV file. 
  # Format: Student ID,Course ID,First Name,Initials,Surname,Mark,Assessment,Status
  # Only Student ID, First Name, and Surname are used.
  def import_users_from_csv(file)
    team_cache = {}

    CSV.foreach(file) do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /Subject Code/
      next if row[5] !~ /^LA\d/

      subject_code, username  = row[0..1]
      first_name, last_name   = [row[2], row[3]].map{|name| name.titleize }
      email, class_id         = row[4..5]

      project_participant = User.find_or_create_by_username(:username => username) {|new_user|
        new_user.username           = username
        new_user.first_name         = first_name
        new_user.last_name          = last_name
        new_user.email              = email
        new_user.nickname           = first_name
        new_user.encrypted_password = BCrypt::Password.create("password")
        new_user.system_role        = "user"
      }

      project_participant.save!(:validate => false) unless project_participant.persisted?

      user_not_in_project = TeamMembership.joins(:project => :project_template).where(
        :user_id => project_participant.id,
        :projects => {:project_template_id => id}
      ).count == 0

      team = team_cache[class_id] || Team.where(:official_name => class_id, :project_template_id => id).first
      team_cache[class_id] ||= team
      
      # Add the user to the project (if not already in there)
      if user_not_in_project
        add_user(project_participant.id, team.id, "student")
      end
    end
  end

  def import_teams_from_csv(file)
    CSV.foreach(file) do |row|
      next if row[0] =~ /Subject Code/ # Skip header

      class_type, class_id, day, time, location, tutor_username = row[2..-1]
      next if class_type !~ /Lab/

      Team.find_or_create_by_project_template_id_and_official_name(id, class_id) do |team|
        team.meeting_day      = day
        team.meeting_time     = time
        team.meeting_location = location
        
        user_for_tutor = User.where(:username => tutor_username).first
        team.user_id          = user_for_tutor.id
      end
    end
  end

  def import_tasks_from_csv(file)
    project_cache = nil

    CSV.foreach(file) do |row|
      next if row[0] =~ /Task Name/ # Skip header

      name, abbreviation, description, weighting, required, target_date, abbreviation = row[0..5]
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
      task_template = TaskTemplate.find_or_create_by_project_template_id_and_name(id, name) do |task_template|
        task_template.name                        = name
        task_template.project_template_id         = id
        task_template.abbreviation                = abbreviation
        task_template.description                 = description
        task_template.weighting                   = BigDecimal.new(weighting)
        task_template.required                    = ["Yes", "y", "Y", "yes", "true", "1"].include? required
        task_template.target_date                 = Time.zone.parse(target_date)
      end

      task_template.save! unless task_template.persisted?

      project_cache ||= Project.where(:project_template_id => id)

      project_cache.each do |project|
        Task.create(
          task_template_id: task_template.id,
          project_id:       project.id,
          task_status_id:   1,
          awaiting_signoff: false,
          completion_date:  nil
        )
      end
    end
  end

  def status_distribution
    projects = Project.where(:project_template_id => id)
    project_count = projects.length
    
    status_totals = {
      :ahead => 0,
      :on_track => 0,
      :behind => 0,
      :danger => 0,
      :doomed => 0,
      :not_started => 0,
      :total => 0
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