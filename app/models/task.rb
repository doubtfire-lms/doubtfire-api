class Task < ActiveRecord::Base
  attr_accessible :awaiting_signoff

  # Model associations
  belongs_to :task_template         # Foreign key
  belongs_to :project               # Foreign key
  belongs_to :task_status           # Foreign key
end