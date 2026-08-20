module Entities
  class CommunicationConditionEntity < Grape::Entity
    expose :id
    expose :type
    expose :communication_id, as: :communication_rule_id
    expose :operator
    expose :target_grade
    expose :task_definition_id
    expose :task_statuses
    expose :task_status_count
    expose :task_target_grade
    expose :last_sign_in_at
    expose :activity_days
    expose :spec_con_days
    expose :tutorial_id
    expose :tutorial_stream_id
    expose :campus_id
    expose :submitted_portfolio
  end
end
