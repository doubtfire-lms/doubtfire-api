require 'grape'
require 'grape-swagger'
require 'authorisation'

module AuthHelpers
  def warden
    env['warden']
  end

  def authenticated?
    if params[:auth_token]
      user_by_token = User.find_by_auth_token(params[:auth_token])
    else
      user_by_token = nil
    end

    if warden.authenticated?
      return true
    elsif params[:auth_token] && user_by_token && user_by_token.auth_token_expiry && user_by_token.auth_token_expiry > DateTime.now
      return true
    else
      sleep((200 + rand(200)) / 1000.0)
      error!({"error" => "Could not authenticate with token. Token invalid or has expired"}, 401)
    end
  end
  
  def current_user
    warden.user || User.find_by_auth_token(params[:auth_token])
  end

  # Add the required auth_token to each of the routes for the provided
  # Grape::API.
  #
  def self.add_auth_to(service)
    service.routes.each do |route|
      options = route.instance_variable_get("@options")
      unless options[:params]["auth_token"]
        options[:params]["auth_token"] = {:required=>true, :type=>"String", :desc=>"Authentication token"}
      end
    end
  end
end

module Api
  class Root < Grape::API
    helpers do
      def logger
        API.logger
      end
    end
    prefix 'api'
    format :json
    formatter :json, Grape::Formatter::ActiveModelSerializers
    rescue_from :all

    mount Api::Auth
    mount Api::Projects
    mount Api::Students
    mount Api::Tasks
    mount Api::Tutorials
    mount Api::UnitRoles
    mount Api::Units
    mount Api::Users
    mount Api::Submission::Generate
    mount Api::Submission::PortfolioEvidence

    AuthHelpers.add_auth_to Api::Units
    AuthHelpers.add_auth_to Api::Projects
    AuthHelpers.add_auth_to Api::Students
    AuthHelpers.add_auth_to Api::Tasks
    AuthHelpers.add_auth_to Api::Tutorials
    AuthHelpers.add_auth_to Api::Users
    AuthHelpers.add_auth_to Api::UnitRoles
    AuthHelpers.add_auth_to Api::Submission::PortfolioEvidence

    add_swagger_documentation base_path: "",
                            # api_version: 'api',
                            hide_documentation_path: true
  end
end
