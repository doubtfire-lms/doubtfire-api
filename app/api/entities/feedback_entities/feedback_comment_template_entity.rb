module Entities
  class FeedbackCommentTemplateEntity < Grape::Entity
    expose :id
    expose :comment_text_situation
    expose :comment_text_next_action
  end
end
