module Entities
  class FeedbackTemplateChipEntity < Grape::Entity
    expose :id
    expose :abbreviation
    expose :order
    expose :chip_text
    expose :description
    expose :comment_text
    expose :summary_text
    expose :task_status
  end
end
