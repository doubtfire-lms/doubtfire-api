module Entities
  class OverseerAssessmentEntity < Grape::Entity
    expose :id
    expose :task_id
    expose :submission_history_id
    expose :submission_timestamp
    expose :result_task_status
    expose :status
    expose :created_at
    expose :updated_at

    expose :total_steps
    expose :passed_steps

    expose :has_submission_files?, as: :has_submission_files
  end
end
