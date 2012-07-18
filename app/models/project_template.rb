class ProjectTemplate < ActiveRecord::Base
  attr_accessible :description, :end_date, :name, :start_date

  # Model associations
  has_many :task_templates
  has_many :projects
  has_many :teams

end