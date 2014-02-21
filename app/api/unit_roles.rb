require 'grape'

module Api
  class UnitRoles < Grape::API
    helpers AuthHelpers

    before do
      authenticated?
    end

    desc "Get unit roles"
    get '/unit_roles' do
      @unit_roles = UnitRole.for_user current_user

      if params[:unit_id]
        @unit_roles = @unit_roles.where(unit_id: params[:unit_id])
      end

      @unit_roles
    end
  end
end
