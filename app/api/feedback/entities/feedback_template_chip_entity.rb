module Feedback
  module Entities
    class FeedbackTemplateChipEntity < Grape::Entity
      expose :id
      expose :type
      expose :chip_text
      expose :description
      expose :task_status
      expose :parent_chip_id
      expose :learning_outcome
      expose :related_entity
      expose :section

      expose :comment_text
      expose :summary_text
    end
  end
end
