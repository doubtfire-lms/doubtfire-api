class ProjectStatus < ActiveRecord::Base
  attr_accessible :health

  # Model associations
  has_many :projects
end
