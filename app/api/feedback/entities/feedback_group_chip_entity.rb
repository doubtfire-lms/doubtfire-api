module Feedback
  module Entities
    class FeedbackGroupChipEntity < Grape::Entity
      expose :id
      expose :type
      expose :chip_text
      expose :description
      expose :parent_chip_id
      expose :learning_outcome_id # becomes id
      expose :related_entity # removed
      expose :section # removed
    end
  end
end
