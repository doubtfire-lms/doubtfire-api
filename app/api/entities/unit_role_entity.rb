module Entities
  class UnitRoleEntity < Grape::Entity

    def staff?(my_role)
      [Role.tutor_id, Role.convenor_id, Role.admin_id, Role.auditor_id].include?(my_role.id) unless my_role.nil?
    end

    expose :id
    expose :role do |unit_role, options| unit_role.role.name end
    expose :user, using: Entities::Minimal::MinimalUserEntity
    expose :unit, using: Entities::Minimal::MinimalUnitEntity, unless: :in_unit
    expose :observer_only

    expose :mentor_id, if: ->(unit_role, options) { staff?(options[:my_role]) }
    expose :tutor_note_count, if: ->(unit_role, options) { unit_role.unit.unit_role_for(options[:user])&.id == unit_role.id } do |unit_role, options|
      unit_role.tutor_notes
               .where(read_by_unit_role: false)
               .where.not(user_id: options[:user].id)
               .count
    end

    expose :can_mark_overflow_tasks, if: ->(unit_role, options) { staff?(options[:my_role]) }
  end
end
