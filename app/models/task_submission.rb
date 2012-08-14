class TaskSubmission < ActiveRecord::Base
  belongs_to :task
  belongs_to :assessor, :class_name => "User", :foreign_key => 'assessor_id'
  attr_accessible :task, :submission_time, :assessment_time, :outcome, :assessor
end