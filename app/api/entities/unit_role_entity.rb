module Entities
  class UnitRoleEntity < Grape::Entity
    expose :id
    expose :role do |unit_role, options| unit_role.role.name end
    expose :user, using: Entities::Minimal::MinimalUserEntity
    expose :unit, using: Entities::Minimal::MinimalUnitEntity, unless: :in_unit
    expose :observer_only
    # TODO: expose to staff only
    expose :mentor_id
  end
end
