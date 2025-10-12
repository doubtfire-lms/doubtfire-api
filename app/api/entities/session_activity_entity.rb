module Entities
  class SessionActivityEntity < Grape::Entity
    expose :id
    expose :marking_session_id
    expose :action
    expose :project_id
    expose :task_id
    expose :task_definition_id
    expose :created_at
    expose :updated_at
  end
end
