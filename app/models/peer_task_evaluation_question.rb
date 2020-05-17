class PeerTaskEvaluationQuestion < ActiveRecord::Base
  include ApplicationHelper

  has_many :task_evaluation_question  
end