module Entities
  class SubmissionHistoryEntity < Grape::Entity
    expose :id
    expose :task_id
    expose :submission_timestamp
    expose :created_at
    expose :has_submission_files?, as: :has_submission_files

    expose :overseer_assessment_id do |history|
      history.overseer_assessment&.id
    end
  end
end
