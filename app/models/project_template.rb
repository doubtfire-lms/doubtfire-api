require 'csv'
require 'bcrypt'

class ProjectTemplate < ActiveRecord::Base
  attr_accessible :official_name, :description, :end_date, :name, :start_date
  validates_presence_of :name, :description, :start_date, :end_date

  # Accessor to allow setting of convenors via the new/edit form
  attr_accessor :convenors  

  # Model associations. 
  # When a ProjectTemplate is destroyed, any TaskTemplates, Teams, and ProjectConvenor instances will also be destroyed.
  has_many :task_templates, :dependent => :destroy	  			
  has_many :projects, :dependent => :destroy					 
  has_many :teams, :dependent => :destroy
  has_many :project_convenors, :dependent => :destroy
  
  # Adds a user to this project.
  def add_user(user_id, team_id, project_role)
    # Put the user in the appropriate team (ie. create a new team_membership)
    TeamMembership.populate(1) do |team_membership|
      team_membership.team_id = team_id
      team_membership.user_id = user_id

      # Create a project instance
      Project.populate(1) do |project|
        project.project_status_id = 1   # @TODO: Remove hard-coded value
        project.project_template_id = id
        project.project_role = project_role

        # Set the foreign keys for the 1:1 relationship
        project.team_membership_id = team_membership.id
        team_membership.project_id = project.id

        # Create task instances for the project
        task_templates_for_project = TaskTemplate.where(:project_template_id => self.id)
        task_templates_for_project.each do |task_template|
          Task.populate(1) do |task|
            task.task_template_id = task_template.id
            task.project_id       = project.id
            task.task_status_id   = 1     # @TODO: Remove hard-coded value
            task.awaiting_signoff = false
            task.completion_date  = nil
          end
        end
      end
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
        new_user.system_role        = "student"
      }

      project_participant.save!(:validate => false) unless project_participant.persisted?

      user_not_in_project = TeamMembership.joins(:project => :project_template).where(
        :user_id => project_participant.id,
        :projects => {:project_template_id => id}
      ).count == 0

      team = team_cache[class_id] || Team.where(:official_name => class_id).first
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
    CSV.foreach(file) do |row|
      next if row[0] =~ /Task Name/ # Skip header

      name, description, weighting, required, target_date = row

      # TODO: Should background/task queue this work
      task = TaskTemplate.find_or_create_by_name(name) do |task_template|
        task_template.name                        = name
        task_template.project_template_id         = id
        task_template.description                 = description
        task_template.weighting                   = BigDecimal.new(weighting)
        task_template.required                    = ["Yes", "y", "Y", "yes", "true"].include? required
        task_template.recommended_completion_date = Time.zone.parse(target_date)
      end

      task.save! unless task.persisted?
    end
  end

  def status_distribution
    project_instances = Project.where(:project_template_id => id)
    total_project_instances = project_instances.length
    
    status_totals = {
      :ahead => 0.0,
      :on_track => 0.0,
      :behind => 0.0,
      :danger => 0.0,
      :doomed => 0.0,
      :total => 0.0
    }

    project_instances.each do |project|     
      status_totals[project.relative_progress] += (1.0 / total_project_instances * 100.0)
    end

    status_totals[:total] = total_project_instances
    Hash[status_totals.sort_by{ |status, percentage| percentage }.reverse]
  end   
end













