class Project < ActiveRecord::Base
  attr_accessible :project_role

  # Model associations
  belongs_to :team              # Foreign key
  belongs_to :project_status    # Foreign key
  belongs_to :project_template  # Foreign key
  belongs_to :team_membership   # Foreign key

  has_many :tasks
end
