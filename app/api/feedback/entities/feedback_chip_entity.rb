module Feedback
  module Entities
    class FeedbackChipEntity < Grape::Entity
      expose :id
      expose :type
      expose :chip_text
      expose :description
      expose :task_status_id
      expose :parent_chip_id
      expose :learning_outcome_id
      expose :summary_text
      expose :comment_text
    end
  end
end
