module Feedback
  module Entities
    class FeedbackGroupChipEntity < Grape::Entity
      expose :id
      expose :type do |chip|
        case chip.type
        when 'Feedback::FeedbackTemplateChip'
          'template'
        when 'Feedback::FeedbackGroupChip'
          'group'
        else
          'unknown'
        end
      end
      expose :chip_text
      expose :description
      expose :parent_chip_id
      expose :learning_outcome_id
    end
  end
end
