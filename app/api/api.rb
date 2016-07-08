require 'grape'
require 'grape-swagger'

module Api
  class Root < Grape::API
    helpers AuthorisationHelpers
    helpers LogHelper
    helpers AuthHelpers

    prefix 'api'
    format :json
    formatter :json, Grape::Formatter::ActiveModelSerializers
    # rescue_from :all

    #
    # Mount the api modules
    #
    mount Api::Auth
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

    #
    # Add auth details to all end points
    #
    AuthHelpers.add_auth_to Api::GroupSets
    AuthHelpers.add_auth_to Api::Units
    AuthHelpers.add_auth_to Api::Projects
    AuthHelpers.add_auth_to Api::Students
    AuthHelpers.add_auth_to Api::Tasks
    AuthHelpers.add_auth_to Api::TaskComments
    AuthHelpers.add_auth_to Api::TaskDefinitions
    AuthHelpers.add_auth_to Api::Tutorials
    AuthHelpers.add_auth_to Api::Users
    AuthHelpers.add_auth_to Api::UnitRoles
    AuthHelpers.add_auth_to Api::LearningOutcomes
    AuthHelpers.add_auth_to Api::LearningAlignment
    AuthHelpers.add_auth_to Api::Submission::PortfolioApi
    AuthHelpers.add_auth_to Api::Submission::PortfolioEvidenceApi
    AuthHelpers.add_auth_to Api::Submission::BatchTask

    add_swagger_documentation base_path: "",
                          # api_version: 'api',
                  hide_documentation_path: true
  end
end
