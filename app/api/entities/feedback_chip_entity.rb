module Entities
  class FeedbackChipEntity < Grape::Entity
    expose :id
    expose :title
    expose :parentChipId
    expose :childChipId
    expose :belongsTo
  end
end
