class TaskEvaluationQuestion < ActiveRecord::Base
  include ApplicationHelper

  belongs_to :peer_task_evaluation_question
  belongs_to :task_definition
end