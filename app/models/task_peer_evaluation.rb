class TaskPeerEvaluation < ActiveRecord::Base
  include ApplicationHelper

  belongs_to :task_evaluation_question
  belongs_to :project

end