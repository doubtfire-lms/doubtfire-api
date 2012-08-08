require 'csv'
require 'bcrypt'

class ProjectTemplate < ActiveRecord::Base
  attr_accessible :description, :end_date, :name, :start_date
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
        project.project_template_id = self.id
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
    CSV.foreach(file) do |row|
      
      # Make sure we're not looking at the header or an empty line
      next if row[0][0] != '['     
      next if row.length != 8

      username = row[0][1..-2]    # 1st column: Student ID with [] trimmed off
      first_name, last_name = [row[2], row[4]].map{|name| name.titleize }
      team_id = 1 
      
      user_to_add = User.where(:username => username)
      
      # If the user doesn't exist in the system yet, create an account for them.
      if user_to_add.count == 0
        logger.info("==========================================================CREATING USER #{username}")
        user = User.where(:username => username).first_or_initialize

        user.username           = username
        user.first_name         = first_name
        user.last_name          = last_name
        user.email              = "#{username}@swin.edu.au"
        user.encrypted_password = BCrypt::Password.create("password")
        user.nickname           = "noob"

        user.save!(:validate => false)

        # Rails.logger.info("==========================================================#{user_to_add.username}")
        user_not_in_project = TeamMembership.joins(:project => :project_template).where(
          :user_id => user.id,
          :projects => {:project_template_id => self.id}
        ).count == 0
      
        # Add the user to the project (if not already in there)
        if user_not_in_project
          self.add_user(user.id, team_id, "student")    # @TODO: Get tute ID somehow instead of hard-coding 
        else
          logger.info("USER #{user.id}: #{username} - #{user.full_name} ALREADY IN PROJECT #{self.name}")
        end
      else
        logger.info("==========================================================USER #{username} ALREADY EXISTS")
      end
    end
  end
end