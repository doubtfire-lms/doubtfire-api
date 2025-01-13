module Feedback
  module Entities
    class FeedbackChipEntity < Grape::Entity
      expose :id
      expose :type do |chip|
        case chip.type
        when 'FeedbackTemplateChip'
          'template'
        when 'FeedbackGroupChip'
          'group'
        else
          'unknown'
        end
      end
      expose :chip_text
      expose :description
      expose :task_status
      expose :parent_chip_id
      expose :learning_outcome_id
      expose :summary_text
      expose :comment_text
    end
  end
end
