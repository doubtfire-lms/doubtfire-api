require 'grape'

module Api
  class UnitRoles < Grape::API
    helpers AuthHelpers

    before do
      authenticated?
    end

    desc "Get unit roles for authenticated user"
    params do
      optional :unit_id, type: Integer, desc: 'Get user roles in indicated unit'
    end
    get '/unit_roles' do
      unit_roles = UnitRole.for_user current_user

      if params[:unit_id]
        unit_roles = unit_roles.where(unit_id: params[:unit_id])
      end

      unit_roles
    end

    desc "Get a unit_role's details"
    get '/unit_roles/:id' do
      unit_role = UnitRole.find(params[:id])

      if unit_role.user != current_user
        error!({"error" => "Couldn't find UnitRole with id=#{params[:id]}" }, 403)
      end
      # present unit_role, with: Api::Entities::UnitRole
      unit_role
    end
  end
end
