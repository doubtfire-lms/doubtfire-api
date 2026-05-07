module Entities
  class CommunicationRuleEntity < Grape::Entity
    expose :id
    expose :communication_set_id
    expose :name
    expose :operator
    expose :position
    expose :active
    expose :send_log_to_convenors
    expose :communication_conditions,
           as: :conditions,
           using: Entities::CommunicationConditionEntity
    expose :communication_actions,
           as: :actions,
           using: Entities::CommunicationActionEntity
  end
end
