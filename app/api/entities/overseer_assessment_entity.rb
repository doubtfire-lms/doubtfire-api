module Entities
  class OverseerAssessmentEntity < Grape::Entity
    expose :id
    expose :task_id
    expose :submission_timestamp
    expose :result_task_status
    expose :status
    expose :created_at
    expose :updated_at
  end
end
