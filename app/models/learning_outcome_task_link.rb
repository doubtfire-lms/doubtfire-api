class LearningOutcomeTaskLink < ActiveRecord::Base
  belongs_to :task_definition
  belongs_to :task
  belongs_to :learning_outcome
end
