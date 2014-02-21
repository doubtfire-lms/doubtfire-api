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
    end
  end
end
