require 'entities/communication_rule_entity'
require 'entities/communication_set_schedule_entity'

module Entities
  class CommunicationSetEntity < Grape::Entity
    expose :id
    expose :unit_id
    expose :name
    expose :active
    expose :executable?, as: :executable
    expose :communication_set_schedules,
           as: :schedules,
           using: Entities::CommunicationSetScheduleEntity
    expose :communication_rules,
           as: :rules,
           using: Entities::CommunicationRuleEntity
  end
end
