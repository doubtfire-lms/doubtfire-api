require 'grape'
require 'grape-swagger'

module Api
  class Root < Grape::API
    helpers AuthorisationHelpers
    helpers LogHelper
    helpers AuthenticationHelpers

    prefix 'api'
    format :json
    # formatter :json, Grape::Formatter::ActiveModelSerializers

    before do
      header['Access-Control-Allow-Origin'] = '*'
      header['Access-Control-Request-Method'] = '*'
    end

    rescue_from :all do |e|
      case e
      when ActiveRecord::RecordInvalid, Grape::Exceptions::ValidationErrors
        error!(e.message, 400)
      when Grape::Exceptions::MethodNotAllowed
        error!(e.message, 405)
      when ActiveRecord::RecordNotDestroyed
        error!(e.message, 400)
      when ActiveRecord::RecordNotFound
        error!("Unable to find requested #{e.message[/(Couldn't find )(.*)( with)/,2]}", 404)
      else
        logger.error "Unhandled exception: #{e.class}"
        logger.error e.inspect
        logger.error e.backtrace.join("\n")
        error!("Sorry... something went wrong with your request.", 500)
      end
    end

    desc 'Returns your public timeline.' do
      summary 'summary'
      detail 'more details'
      # params  API::Entities::Status.documentation
      # success API::Entities::Entity
      # failure [[401, 'Unauthorized', 'Entities::Error']]
      named 'My named route'
      headers XAuthToken: {
                description: 'Validates your identity',
                required: true
              },
              XOptionalHeader: {
                description: 'Not really needed',
                required: false
              }
      hidden false
      deprecated false
      is_array true
      nickname 'nickname'
      produces ['application/json']
      consumes ['application/json']
      tags ['tag1', 'tag2']
    end
    get :public_timeline do
      "Hello"
    end

    #
    # Mount the api modules
    #
    mount Api::ActivityTypesAuthenticatedApi
    mount Api::ActivityTypesPublicApi
    mount Api::AuthenticationApi
    mount Api::BreaksApi
    mount Api::DiscussionCommentApi
    mount Api::ExtensionCommentsApi
    mount Api::GroupSetsApi
    mount Api::LearningOutcomesApi
    mount Api::LearningAlignmentApi
    mount Api::ProjectsApi
    mount Api::SettingsApi
    mount Api::StudentsApi
    mount Api::Submission::PortfolioApi
    mount Api::Submission::PortfolioEvidenceApi
    mount Api::Submission::BatchTaskApi
    mount Api::TaskCommentsApi
    mount Api::TaskDefinitionsApi
    mount Api::TasksApi
    mount Api::TeachingPeriodsPublicApi
    mount Api::TeachingPeriodsAuthenticatedApi
    mount Api::CampusesPublicApi
    mount Api::CampusesAuthenticatedApi
    mount Api::TutorialsApi
    mount Api::TutorialStreamsApi
    mount Api::TutorialEnrolmentsApi
    mount Api::UnitRolesApi
    mount Api::UnitsApi
    mount Api::UsersApi

    #
    # Add auth details to all end points
    #
    AuthenticationHelpers.add_auth_to Api::ActivityTypesAuthenticatedApi
    AuthenticationHelpers.add_auth_to Api::BreaksApi
    AuthenticationHelpers.add_auth_to Api::DiscussionCommentApi
    AuthenticationHelpers.add_auth_to Api::ExtensionCommentsApi
    AuthenticationHelpers.add_auth_to Api::GroupSetsApi
    AuthenticationHelpers.add_auth_to Api::LearningOutcomesApi
    AuthenticationHelpers.add_auth_to Api::LearningAlignmentApi
    AuthenticationHelpers.add_auth_to Api::ProjectsApi
    AuthenticationHelpers.add_auth_to Api::StudentsApi
    AuthenticationHelpers.add_auth_to Api::Submission::PortfolioApi
    AuthenticationHelpers.add_auth_to Api::Submission::PortfolioEvidenceApi
    AuthenticationHelpers.add_auth_to Api::Submission::BatchTaskApi
    AuthenticationHelpers.add_auth_to Api::TasksApi
    AuthenticationHelpers.add_auth_to Api::TaskCommentsApi
    AuthenticationHelpers.add_auth_to Api::TaskDefinitionsApi
    AuthenticationHelpers.add_auth_to Api::TeachingPeriodsAuthenticatedApi
    AuthenticationHelpers.add_auth_to Api::CampusesAuthenticatedApi
    AuthenticationHelpers.add_auth_to Api::TutorialsApi
    AuthenticationHelpers.add_auth_to Api::TutorialStreamsApi
    AuthenticationHelpers.add_auth_to Api::TutorialEnrolmentsApi
    AuthenticationHelpers.add_auth_to Api::UsersApi
    AuthenticationHelpers.add_auth_to Api::UnitRolesApi
    AuthenticationHelpers.add_auth_to Api::UnitsApi

    # add_swagger_documentation format: :json,
    #                           hide_documentation_path: false,
    #                           api_version: 'v1',
    #                           info: {
    #                             title: "Horses and Hussars",
    #                             description: "Demo app for dev of grape swagger 2.0"
    #                           },
    #                           mount_path: 'swagger_doc'

    add_swagger_documentation \
      base_path: nil,
      api_version: 'v1',
      hide_documentation_path: true,
      info: {
        title: 'Doubtfire API Documentaion',
        description: 'Doubtfire is a modern, lightweight learning management system.',
        license: 'AGPL v3.0',
        license_url: 'https://github.com/doubtfire-lms/doubtfire-api/blob/master/LICENSE'
      },
      mount_path: 'swagger_doc'
  end
end
