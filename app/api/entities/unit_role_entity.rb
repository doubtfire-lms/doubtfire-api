module Api
  module Entities
    class UnitRoleEntity < Grape::Entity
      expose :id
      expose :role do |unit_role, options| unit_role.role.name end
      expose :user_id
      expose :name do |unit_role, options| unit_role.user.name end
      expose :email do |unit_role, options| unit_role.user.email end
    end
  end
end
