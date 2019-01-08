require 'grape'
require 'grape-swagger'

module Api
  class Root < Grape::API
    helpers AuthorisationHelpers
    helpers LogHelper
    helpers AuthenticationHelpers

    prefix 'api'
    format :json
    formatter :json, Grape::Formatter::ActiveModelSerializers

    rescue_from :all do |e|
      case e
      when ActiveRecord::RecordInvalid, Grape::Exceptions::ValidationErrors
        error!(e.message, 400)
      when Grape::Exceptions::MethodNotAllowed
        error!(e.message, 405)
      when ActiveRecord::RecordNotFound
        error!("Unable to find requested #{e.message[/(Couldn't find )(.*)( with)/,2]}", 404)
      else
        logger.error "Unhandled exception: #{e.class}"
        logger.error e.backtrace.join("\n")
        error!("Sorry... something went wrong with your request.", 500)
      end
    end

    #
    # Mount the api modules
    #
    mount Api::Authentication
    mount Api::GroupSets
    mount Api::Projects
    mount Api::Students
    mount Api::Tasks
    mount Api::TaskComments
    mount Api::TaskDefinitions
    mount Api::Tutorials
    mount Api::UnitRoles
    mount Api::Units
    mount Api::Users
    mount Api::LearningOutcomes
    mount Api::LearningAlignment
    mount Api::Submission::Generate
    mount Api::Submission::PortfolioApi
    mount Api::Submission::PortfolioEvidenceApi
    mount Api::Submission::BatchTask
    mount Api::Settings
    mount Api::TeachingPeriodsPublicApi
    mount Api::TeachingPeriodsAuthenticatedApi
    mount Api::Breaks

    #
    # Add auth details to all end points
    #
    AuthenticationHelpers.add_auth_to Api::GroupSets
    AuthenticationHelpers.add_auth_to Api::Units
    AuthenticationHelpers.add_auth_to Api::Projects
    AuthenticationHelpers.add_auth_to Api::Students
    AuthenticationHelpers.add_auth_to Api::Tasks
    AuthenticationHelpers.add_auth_to Api::TaskComments
    AuthenticationHelpers.add_auth_to Api::TaskDefinitions
    AuthenticationHelpers.add_auth_to Api::Tutorials
    AuthenticationHelpers.add_auth_to Api::Users
    AuthenticationHelpers.add_auth_to Api::UnitRoles
    AuthenticationHelpers.add_auth_to Api::LearningOutcomes
    AuthenticationHelpers.add_auth_to Api::LearningAlignment
    AuthenticationHelpers.add_auth_to Api::Submission::PortfolioApi
    AuthenticationHelpers.add_auth_to Api::Submission::PortfolioEvidenceApi
    AuthenticationHelpers.add_auth_to Api::Submission::BatchTask
    AuthenticationHelpers.add_auth_to Api::TeachingPeriodsAuthenticatedApi
    AuthenticationHelpers.add_auth_to Api::Breaks

    add_swagger_documentation \
      base_path: nil,
      add_version: false,
      hide_documentation_path: true,
      info: {
        title: 'Doubtfire API Documentaion',
        description: 'Doubtfire is a modern, lightweight learning management system.',
        license: 'AGPL v3.0',
        license_url: 'https://github.com/doubtfire-lms/doubtfire-api/blob/master/LICENSE'
      }
  end
end
