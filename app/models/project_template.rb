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
  
end