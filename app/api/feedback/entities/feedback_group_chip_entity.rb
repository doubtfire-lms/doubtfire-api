module Feedback
  module Entities
    class FeedbackGroupChipEntity < Grape::Entity
      expose :id
      expose :type
      expose :chip_text
      expose :description
      expose :parent_chip_id
      expose :learning_outcome
      expose :related_entity
      expose :section
    end
  end
end
