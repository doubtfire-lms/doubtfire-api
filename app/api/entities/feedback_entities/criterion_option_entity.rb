module Entities
  class CriterionOptionEntity < Grape::Entity
    expose :id
    expose :task_status_id # TODO: ... check this?
    expose :resolved_message_text
    expose :unresolved_message_text
  end
end
