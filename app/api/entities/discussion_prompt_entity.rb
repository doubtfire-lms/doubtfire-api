module Entities
  class DiscussionPromptEntity < Grape::Entity
    expose :id
    expose :task_definition_id
    expose :project_id
    expose :created_by_id
    expose :content
    expose :weight
    expose :discussed_at
  end
end
