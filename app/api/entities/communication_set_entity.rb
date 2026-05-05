require 'entities/communication_rule_entity'

module Entities
  class CommunicationSetEntity < Grape::Entity
    expose :id
    expose :unit_id
    expose :name
    expose :active
    expose :communication_rules,
           as: :rules,
           using: Entities::CommunicationRuleEntity
  end
end
