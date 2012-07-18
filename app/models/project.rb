class Project < ActiveRecord::Base
  attr_accessible :description, :end_date, :name, :start_date

  # Model associations
  has_many :tasks
  has_many :project_memberships
  has_many :teams
  has_many :project_administrators

end