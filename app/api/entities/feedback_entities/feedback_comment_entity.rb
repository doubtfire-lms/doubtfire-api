module Entities
  class FeedbackCommentEntity < Grape::Entity
    expose :id
    expose :comment
  end
end
