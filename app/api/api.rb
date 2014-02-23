require 'grape'

module AuthHelpers
  def warden
    env['warden']
  end

  def authenticated?
    if warden.authenticated?
      return true
    elsif params[:auth_token] and
      User.find_by_authentication_token(params[:auth_token]) and
      User.find_by_authentication_token(params[:auth_token]).auth_token_expiry > DateTime.now
      return true
    else
      error!({"error" => "Unauth 401. Token invalid or expired"}, 401)
    end
  end
  
  def current_user
    warden.user ||  User.find_by_authentication_token(params[:auth_token])
  end
end

module Api
  class Root < Grape::API
    prefix 'api'
    format :json
    formatter :json, Grape::Formatter::ActiveModelSerializers

    mount Api::Units
    mount Api::Projects
    mount Api::Tasks
    mount Api::Users
    mount Api::UnitRoles
    mount Api::UserRoles
  end
end
