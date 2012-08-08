class TaskSubmission < ActiveRecord::Base
  belongs_to :task
  attr_accessible :task, :submission_time, :assessment_time, :outcome
end
