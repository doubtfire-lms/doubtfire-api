module Entities
  class OverseerAssessmentEntity < Grape::Entity
    expose :id
    expose :task_id
    expose :submission_timestamp
    expose :result_task_status
    expose :status
    expose :created_at
    expose :updated_at

    # TODO: filter permissions, create a custom map of what should be exposed but on the original step
    # expose :overseer_step_results, using: OverseerStepResultEntity

    expose :total_steps
    expose :passed_steps
  end
end
