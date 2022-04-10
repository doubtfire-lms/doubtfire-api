module Entities
  class FocusEntity < Grape::Entity
    expose :id
    expose :title
    expose :description
    expose :color
    expose :grade_criteria
  end

  class TaskDefinitionRequiredFocus < Grape::Entity
    expose :id
    expose :focus_id
    expose :task_definition_id
  end
end
