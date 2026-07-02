require 'grape'
require 'grape-swagger'
require 'grape-swagger/entity'

class ApiRoot < Grape::API
  helpers AuthorisationHelpers
  helpers LogHelper
  helpers AuthenticationHelpers

  prefix 'api'
  format :json

  before do
    header['Access-Control-Allow-Origin'] = '*'
    header['Access-Control-Request-Method'] = '*'

    Thread.current.thread_variable_set(:ip, request.ip)
  end

  rescue_from :all do |e|
    case e
    when ActiveRecord::RecordInvalid, Grape::Exceptions::ValidationErrors, ActiveRecord::RecordNotDestroyed
      message = e.message
      status = 400
    when ActiveRecord::InvalidForeignKey
      message = "This operation has been rejected as it would break data integrity. Ensure that related values are deleted or updated before trying again."
      status = 400
    when Grape::Exceptions::MethodNotAllowed
      message = e.message
      status = 405
    when ActiveRecord::RecordNotFound
      message = "Unable to find requested #{e.message[/(Couldn't find )(.*)( with)/, 2]}"
      status = 404
    when ActionController::ParameterMissing
      message = "Missing value for #{e.param}"
      status = 400
    when ActiveRecord::ConnectionTimeoutError
      message = 'There is currently high load on the system. Please wait a moment and try again.'
      status = 503
    else
      # rubocop:disable Rails/Output
      puts e.inspect unless Rails.env.production?
      # rubocop:enable Rails/Output

      logger.error "Unhandled exception: #{e.class}"
      logger.error e.inspect
      logger.error e.backtrace.join("\n")
      message = "Sorry... something went wrong with your request."
      status = 500
    end
    Sentry.capture_exception(e)
    Rack::Response.new({ error: message }.to_json, status, { 'Content-type' => 'text/error' })
  end

  #
  # Mount the api modules
  #
  mount Admin::OverseerAdminApi
  mount ActivityTypesAuthenticatedApi
  mount ActivityTypesPublicApi
  mount AuthenticationApi
  mount BreaksApi
  mount DiscussionCommentApi
  mount EngagementsApi
  mount ExtensionCommentsApi
  mount ScormExtensionCommentsApi
  mount GroupSetsApi
  mount LearningOutcomesApi
  mount ProjectsApi
  mount SettingsApi
  mount StudentsApi
  mount Submission::PortfolioApi
  mount Submission::PortfolioEvidenceApi
  mount Submission::BatchTaskApi
  mount TaskCommentsApi
  mount TaskDefinitionsApi
  mount TasksApi
  mount Similarity::TaskSimilarityApi
  mount TeachingPeriodsPublicApi
  mount TeachingPeriodsAuthenticatedApi
  mount StaffNotesApi
  mount SidekiqApi
  mount LtiApi if Doubtfire::Application.config.lti_enabled
  mount TaskPrerequisitesApi
  mount CommunicationRulesApi

  mount Tii::TurnItInApi
  mount Tii::TurnItInHooksApi
  mount Tii::TiiGroupAttachmentApi
  mount Tii::TiiActionApi

  mount ScormApi
  mount TestAttemptsApi
  mount CampusesPublicApi
  mount CampusesAuthenticatedApi
  mount TutorialsApi
  mount TutorialStreamsApi
  mount TutorialEnrolmentsApi
  mount UnitRolesApi
  mount UnitsApi
  mount TutorNotesApi

  mount D2lIntegrationApi::D2lApi
  mount D2lIntegrationApi::OauthPublicApi

  mount UsersApi
  mount WebcalApi
  mount WebcalPublicApi
  mount MarkingSessionsApi
  mount DiscussionPromptsApi
  mount OverseerStepsApi

  mount Feedback::FeedbackChipApi

  #
  # Add auth details to all end points
  #
  AuthenticationHelpers.add_auth_to Admin::OverseerAdminApi

  AuthenticationHelpers.add_auth_to ActivityTypesAuthenticatedApi
  AuthenticationHelpers.add_auth_to BreaksApi
  AuthenticationHelpers.add_auth_to DiscussionCommentApi
  AuthenticationHelpers.add_auth_to EngagementsApi
  AuthenticationHelpers.add_auth_to ExtensionCommentsApi
  AuthenticationHelpers.add_auth_to ScormExtensionCommentsApi
  AuthenticationHelpers.add_auth_to GroupSetsApi
  AuthenticationHelpers.add_auth_to LearningOutcomesApi
  AuthenticationHelpers.add_auth_to ProjectsApi
  AuthenticationHelpers.add_auth_to StudentsApi
  AuthenticationHelpers.add_auth_to Submission::PortfolioApi
  AuthenticationHelpers.add_auth_to Submission::PortfolioEvidenceApi
  AuthenticationHelpers.add_auth_to Submission::BatchTaskApi
  AuthenticationHelpers.add_auth_to TasksApi
  AuthenticationHelpers.add_auth_to Similarity::TaskSimilarityApi
  AuthenticationHelpers.add_auth_to TaskCommentsApi
  AuthenticationHelpers.add_auth_to TaskDefinitionsApi
  AuthenticationHelpers.add_auth_to TeachingPeriodsAuthenticatedApi
  AuthenticationHelpers.add_auth_to StaffNotesApi
  AuthenticationHelpers.add_auth_to SidekiqApi
  AuthenticationHelpers.add_auth_to LtiApi if Doubtfire::Application.config.lti_enabled
  AuthenticationHelpers.add_auth_to TaskPrerequisitesApi
  AuthenticationHelpers.add_auth_to CommunicationRulesApi

  AuthenticationHelpers.add_auth_to Tii::TurnItInApi
  AuthenticationHelpers.add_auth_to Tii::TiiGroupAttachmentApi
  AuthenticationHelpers.add_auth_to Tii::TiiActionApi

  AuthenticationHelpers.add_auth_to CampusesAuthenticatedApi
  AuthenticationHelpers.add_auth_to TutorialsApi
  AuthenticationHelpers.add_auth_to TutorialStreamsApi
  AuthenticationHelpers.add_auth_to TutorialEnrolmentsApi
  AuthenticationHelpers.add_auth_to UsersApi
  AuthenticationHelpers.add_auth_to UnitRolesApi
  AuthenticationHelpers.add_auth_to UnitsApi
  AuthenticationHelpers.add_auth_to WebcalApi
  AuthenticationHelpers.add_auth_to ScormApi
  AuthenticationHelpers.add_auth_to TestAttemptsApi

  AuthenticationHelpers.add_auth_to D2lIntegrationApi::D2lApi
  AuthenticationHelpers.add_auth_to Feedback::FeedbackChipApi
  AuthenticationHelpers.add_auth_to MarkingSessionsApi
  AuthenticationHelpers.add_auth_to DiscussionPromptsApi
  AuthenticationHelpers.add_auth_to OverseerStepsApi
  AuthenticationHelpers.add_auth_to TutorNotesApi

  add_swagger_documentation \
    base_path: nil,
    doc_version: 'v11.0.0',
    hide_documentation_path: false,
    info: {
      title: 'Doubtfire API Documentation',
      description: 'Doubtfire is a modern, lightweight learning management system.',
      license: 'AGPL v3.0',
      license_url: 'https://github.com/doubtfire-lms/doubtfire-api/blob/master/LICENSE'
    },
    mount_path: 'swagger_doc'
end
