class TaskInstance < ActiveRecord::Base
  attr_accessible :awaiting_signoff

  # Model associations
  belongs_to :task                 # Foreign key
  belongs_to :project_membership   # Foreign key
  belongs_to :task_status          # Foreign key
end