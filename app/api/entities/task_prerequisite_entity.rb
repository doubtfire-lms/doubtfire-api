module Entities
  class TaskPrerequisiteEntity < Grape::Entity
    expose :id
    expose :task_definition_id
    expose :prerequisite_id
    expose :task_status do |task_prerequisite|
      TaskStatus.find(task_prerequisite.task_status_id).status_key
    end
  end
end
