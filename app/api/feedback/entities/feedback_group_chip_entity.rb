module Feedback
  module Entities
    class FeedbackGroupChipEntity < Grape::Entity
      expose :id
      expose :title
      expose :parent_chip_id
      expose :child_chip_id
      expose :belongs_to
      expose :belongs_to_tlo
    end
  end
end
