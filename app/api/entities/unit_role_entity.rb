module Entities
  class UnitRoleEntity < Grape::Entity
    expose :id
    expose :role do |unit_role, options| unit_role.role.name end
    expose :user, using: Entities::Minimal::MinimalUserEntity
    expose :unit, using: Entities::Minimal::MinimalUnitEntity, unless: :in_unit
    expose :observer_only

    expose :mentor_id, if: ->(unit_role, options) { unit_role.unit.unit_role_for(options[:user]) }
    expose :tutor_note_count, if: ->(unit_role, options) { unit_role.unit.unit_role_for(options[:user])&.id == unit_role.id } do |unit_role, options|
      # TODO: get unread tutor notes only
      unit_role.unit.unit_role_for(options[:user]).tutor_notes.count
    end
  end
end
