module Entities
  class DiscussionPromptEntity < Grape::Entity
    expose :id
    expose :task_definition_id
    expose :content
    expose :weight
  end
end
