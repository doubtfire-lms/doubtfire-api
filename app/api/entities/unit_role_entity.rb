module Entities
  class UnitRoleEntity < Grape::Entity
    expose :id
    expose :role do |unit_role, options| unit_role.role.name end
    expose :user_id
    expose :name do |unit_role, options| unit_role.user.name end
    expose :email do |unit_role, options| unit_role.user.email end
    expose :unit_id, unless: :in_unit
  end

  class UnitRoleWithUnitEntity < UnitRoleEntity
    expose :unit_code do |unit_role, options| unit_role.unit.code end
    expose :unit_name do |unit_role, options| unit_role.unit.name end
    expose :start_date do |unit_role, options| unit_role.unit.start_date end
    expose :end_date do |unit_role, options| unit_role.unit.end_date end
    expose :teaching_period_id do |unit_role, options| unit_role.unit.teaching_period_id end
    expose :active do |unit_role, options| unit_role.unit.active end
  end
end
