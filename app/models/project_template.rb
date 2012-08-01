class ProjectTemplate < ActiveRecord::Base
  attr_accessible :description, :end_date, :name, :start_date
  validates_presence_of :name, :description, :start_date, :end_date

  # Accessor to allow setting of convenors via the new/edit form
  attr_accessor :convenors  

  # Model associations. 
  # When a ProjectTemplate is destroyed, any TaskTemplates, Teams, and ProjectAdministrator instances will also be destroyed.
  has_many :task_templates, :dependent => :destroy	  			
  has_many :projects, :dependent => :destroy					 
  has_many :teams, :dependent => :destroy
  has_many :project_administrators, :dependent => :destroy
  
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
            task.task_template_id = user_id
            task.project_id = project.id
            task.task_status_id = 1     # @TODO: Remove hard-coded value
            task.awaiting_signoff = false
          end
        end
      end
    end
  end
end