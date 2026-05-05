# frozen_string_literal: true

require File.expand_path('../boot', __FILE__)
require 'rails/all'
require 'csv'
require 'yaml'
require 'bunny-pub-sub/services_manager'

# Precompile assets before deploying to production
if defined?(Bundler)
  Bundler.require(*Rails.groups(assets: %w(development test)))
end

module Doubtfire
  #
  # Doubtfire generic application configuration
  #
  class Application < Rails::Application
    config.load_defaults 7.0
    config.credentials.content_path = Rails.root.join('config/credentials/credentials.yml.enc')
    config.credentials.key_path = Rails.root.join('config/credentials/master.key')

    # Remove Action Mailbox and Active Storage routes - not used
    initializer(:remove_action_mailbox_and_activestorage_routes, after: :add_routing_paths) do |app|
      app.routes_reloader.paths.delete_if { |path| path =~ /activestorage/ }
      app.routes_reloader.paths.delete_if { |path| path =~ /actionmailbox/ }
    end

    # Load .env variables
    Dotenv::Rails.load

    config.silence_healthcheck_path = "/health"

    # ==> Authentication Method
    # Authentication method default is database, but possible settings
    # are: database, ldap, aaf, or saml. It can be overridden using the DF_AUTH_METHOD
    # environment variable.
    config.auth_method = (ENV['DF_AUTH_METHOD'] || :database).to_sym

    # ==> Student work directory
    # File server location for storing student's work. Defaults to `student_work`
    # directory under root but is overridden using DF_STUDENT_WORK_DIR environment
    # variable.
    config.student_work_dir = ENV['DF_STUDENT_WORK_DIR'] || Rails.root.join('student_work').to_s

    # ==> Archive directory
    # File server location for storing archived student work. Defaults to a subfolder of student work
    # Set using DF_ARCHIVE_DIR environment variable.
    config.archive_dir = ENV.fetch('DF_ARCHIVE_DIR', "#{config.student_work_dir}/archive")

    # Allows for the archiving of units to be automated
    config.archive_units = ENV['DF_ARCHIVE_UNITS'].present? && (ENV['DF_ARCHIVE_UNITS'].to_s.downcase == "true" || ENV['DF_ARCHIVE_UNITS'].to_i == 1)

    # Period for which to keep units
    config.unit_archive_after_period = ENV.fetch('DF_UNIT_ARCHIVE_PERIOD', 2).to_f * 1.year

    # Limit number of pdf generators to run at once
    config.pdfgen_max_processes = ENV['DF_MAX_PDF_GEN_PROCESSES'] || 2

    # Date range for auditors to view
    config.auditor_unit_access_years = ENV.fetch('DF_AUDITOR_UNIT_ACCESS_YEARS', 2).to_f * 1.year

    config.student_import_weeks_before = ENV.fetch('DF_IMPORT_STUDENTS_WEEKS_BEFPRE', 1).to_f * 1.week

    def self.fetch_boolean_env(name)
      %w'true 1'.include?(ENV.fetch(name, 'false').downcase)
    end

    def self.fetch_credential_or_env(*credential_path, env_key:, default: nil)
      credential_value =
        if credential_path.length == 1 && credentials.respond_to?(credential_path.first)
          credentials.public_send(credential_path.first)
        else
          credentials.dig(*credential_path)
        end

      credential_value.nil? ? ENV.fetch(env_key, default) : credential_value
    end

    # ==> Log to stdout
    config.log_to_stdout = Application.fetch_boolean_env('DF_LOG_TO_STDOUT')

    # Have rails report errors and log messages to the following email address where present
    config.email_errors_to = ENV.fetch('DF_EMAIL_ERRORS_TO', nil)

    # ==> JPLAG report directory
    # File server location for storing JPLAG reports. Defaults to `jplag/results`
    # directory under root but is overridden using DF_JPLAG_REPORT_DIR environment
    # variable.
    config.jplag_report_dir = ENV['DF_JPLAG_REPORT_DIR'] || Rails.root.join('jplag/results').to_s
    config.jplag_min_tokens = ENV.fetch('DF_JPLAG_MIN_TOKENS', -1)
    config.jplag_skip_cluster_check = ENV['DF_JPLAG_SKIP_CLUSTER_CHECK'].present? && (ENV['DF_JPLAG_SKIP_CLUSTER_CHECK'].to_s.downcase == "true" || ENV['DF_JPLAG_SKIP_CLUSTER_CHECK'].to_i == 1)

    # ==> File size limits
    # Sets the global file size limit per upload requirement
    # Defaults to 10MB (10,000,000 bytes)
    config.max_file_size = ENV.fetch('DF_MAX_FILE_SIZE', 10_000_000)

    # Prefer encrypted Rails credentials, while keeping env vars as a safe fallback.
    credentials.secret_key_base = Application.fetch_credential_or_env(:secret_key_base, env_key: 'DF_SECRET_KEY_BASE', default: Rails.env.production? ? nil : '9e010ee2f52af762916406fd2ac488c5694a6cc784777136e657511f8bbc7a73f96d59c0a9a778a0d7cf6406f8ecbf77efe4701dfbd63d8248fc7cc7f32dea97')
    credentials.secret_key_attr = Application.fetch_credential_or_env(:secret_key_attr, env_key: 'DF_SECRET_KEY_ATTR', default: Rails.env.production? ? nil : 'e69fc5960ca0e8700844a3a25fe80373b41c0a265d342eba06950113f3766fd983bad9ec51bf36eb615d9711bfe1dd90b8e35f01841b323f604ffee857e32055')
    credentials.secret_key_devise = Application.fetch_credential_or_env(:secret_key_devise, env_key: 'DF_SECRET_KEY_DEVISE', default: Rails.env.production? ? nil : 'f4e23c4388dc600e503a09ad057b8271d8fcf4c2cd6723b44f33db638e49075fe96bc545eed9110ded0c5df505625d4e1c838b718349eecf1d39270d0829d5b9')
    credentials.secret_key_aaf = Application.fetch_credential_or_env(:aaf, :secret_key, env_key: 'DF_SECRET_KEY_AAF', default: Rails.env.production? ? nil : 'secretsecret12345')
    credentials.secret_key_moss = Application.fetch_credential_or_env(:moss, :secret_key, env_key: 'DF_SECRET_KEY_MOSS')

    # ==> LTI settings
    # If enabled, mounts the LTI routes and enables LTI authentication.
    config.lti_enabled = ENV.fetch('LTI_ENABLED', false).to_s.downcase == "true"
    # Shared secret between Ruby on Rails API and the LTI.js API
    # LTI.js will send signed JWT tokens using this secret
    config.lti_api_secret = Application.fetch_credential_or_env(:lti, :shared_api_secret, env_key: 'LTI_SHARED_API_SECRET')

    # ==> Moderation settings
    config.moderation_score_factor = Float(ENV.fetch('MODERATION_SCORE_FACTOR', 1.0))

    # ==> Institution settings
    # Institution YAML and ENV (override) config load
    config.institution = YAML.load_file(Rails.root.join('config/institution.yml').to_s).with_indifferent_access
    config.institution[:name] = ENV['DF_INSTITUTION_NAME'] if ENV['DF_INSTITUTION_NAME']
    config.institution[:email_domain] = ENV['DF_INSTITUTION_EMAIL_DOMAIN'] if ENV['DF_INSTITUTION_EMAIL_DOMAIN']
    config.institution[:host] = ENV['DF_INSTITUTION_HOST'] if ENV['DF_INSTITUTION_HOST']
    config.institution[:cookie_domain] = ENV.fetch('DF_COOKIE_DOMAIN', URI.parse(Doubtfire::Application.config.institution[:host]).host)
    config.institution[:product_name] = ENV['DF_INSTITUTION_PRODUCT_NAME'] if ENV['DF_INSTITUTION_PRODUCT_NAME']

    config.institution[:has_logo] = (ENV['DF_INSTITUTION_HAS_LOGO'].to_s.downcase == "true" || ENV['DF_INSTITUTION_HAS_LOGO'].to_i == 1) if ENV['DF_INSTITUTION_HAS_LOGO']
    config.institution[:logo_url] = ENV['DF_INSTITUTION_LOGO_URL'] if ENV['DF_INSTITUTION_LOGO_URL']
    config.institution[:logo_link_url] = ENV['DF_INSTITUTION_LOGO_LINK_URL'] if ENV['DF_INSTITUTION_LOGO_LINK_URL']

    config.institution[:privacy] = ENV['DF_INSTITUTION_PRIVACY'] if ENV['DF_INSTITUTION_PRIVACY']
    config.institution[:plagiarism] = ENV['DF_INSTITUTION_PLAGIARISM'] if ENV['DF_INSTITUTION_PLAGIARISM']
    # Institution host becomes localhost in development
    config.institution[:host] ||= 'http://localhost:4200' if Rails.env.development?
    config.institution[:settings] = ENV['DF_INSTITUTION_SETTINGS_RB'] if ENV['DF_INSTITUTION_SETTINGS_RB']
    config.institution[:ffmpeg] = ENV['DF_FFMPEG_PATH'] || 'ffmpeg'

    require Rails.root.join("config/#{config.institution[:settings]}").to_s unless config.institution[:settings].nil?

    # ==> SAML2.0 authentication
    if config.auth_method == :saml
      config.saml = HashWithIndifferentAccess.new
      # URL and file path of the XML SAML Metadata (if available).
      config.saml[:SAML_metadata_url] = ENV.fetch('DF_SAML_METADATA_URL', nil)
      config.saml[:SAML_metadata_file_path] = ENV.fetch('DF_SAML_METADATA_FILE_PATH', nil)

      # URL to return the SAML response to (e.g., 'https://doubtfire.edu/api/auth/jwt'
      config.saml[:assertion_consumer_service_url] = ENV.fetch('DF_SAML_CONSUMER_SERVICE_URL', nil)
      # URL of the registered application (e.g., https://doubtfire.unifoo.edu.au)
      config.saml[:entity_id] = ENV.fetch('DF_SAML_SP_ENTITY_ID', nil)
      # The IDP SAML login URL, (e.g., "https://login.microsoftonline.com/xxxx/saml2")
      config.saml[:idp_sso_target_url] = ENV.fetch('DF_SAML_IDP_TARGET_URL', nil)
      # The IDP SAML logout URL, (e.g., "https://login.microsoftonline.com/xxxx/saml2")
      config.saml[:idp_sso_signout_url] = ENV.fetch('DF_SAML_IDP_SIGNOUT_URL', nil)

      # The SAML response certificate and name format (if no XML URL metadata is provided)
      if config.saml[:SAML_metadata_url].nil?
        config.saml[:idp_sso_cert] = ENV.fetch('DF_SAML_IDP_CERT', nil)

        # One of urn:oasis:names:tc:SAML:2.0:nameid-format:persistent, urn:oasis:names:tc:SAML:2.0:nameid-format:transient, urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress
        #        urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified, urn:oasis:names:tc:SAML:1.1:nameid-format:X509SubjectName, urn:oasis:names:tc:SAML:1.1:nameid-format:WindowsDomainQualifiedName
        #        urn:oasis:names:tc:SAML:2.0:nameid-format:kerberos, urn:oasis:names:tc:SAML:2.0:nameid-format:entity
        config.saml[:idp_name_identifier_format] = ENV['DF_SAML_IDP_SAML_NAME_IDENTIFIER_FORMAT'] || "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
      end

      # Check we have all values
      # always need:
      if config.saml[:assertion_consumer_service_url].nil? ||
         config.saml[:entity_id].nil? ||
         config.saml[:idp_sso_target_url].nil?
        raise "Invalid values specified to saml, check the following environment variables: \n  " \
              "key                           => variable set?\n  " \
              "DF_SAML_CONSUMER_SERVICE_URL  => #{!ENV['DF_SAML_CONSUMER_SERVICE_URL'].nil?}\n  " \
              "DF_SAML_SP_ENTITY_ID          => #{!ENV['DF_SAML_SP_ENTITY_ID'].nil?}\n  " \
              "DF_SAML_IDP_SIGNOUT_URL       => #{!ENV['DF_SAML_IDP_SIGNOUT_URL'].nil?}\n  " \
              "DF_SAML_IDP_TARGET_URL        => #{!ENV['DF_SAML_IDP_TARGET_URL'].nil?}\n"
      end

      # If there's no XML url, we need the cert
      if config.saml[:SAML_metadata_url].nil? &&
         config.saml[:SAML_metadata_file_path].nil? &&
         config.saml[:idp_sso_cert].nil?
        raise "Missing IDP certificate for SAML config: #{config.saml.inspect}"
      end
    end

    # ==> AAF authentication
    # Must require AAF devise authentication method.
    if config.auth_method == :aaf
      config.aaf = HashWithIndifferentAccess.new
      # URL of the issuer (i.e., https://rapid.[test.]aaf.edu.au)
      config.aaf[:issuer_url] = ENV['DF_AAF_ISSUER_URL'] || 'https://rapid.test.aaf.edu.au'
      # URL of the registered application (e.g., https://doubtfire.unifoo.edu.au)
      config.aaf[:audience_url] = ENV.fetch('DF_AAF_AUDIENCE_URL', nil)
      # The secure URL within your application that AAF Rapid Connect should
      # POST responses to (e.g., https://doubtfire.unifoo.edu.au/auth/jwt)
      config.aaf[:callback_url] = ENV.fetch('DF_AAF_CALLBACK_URL', nil)
      # URL of the unique url provided by rapid connect used for redirect
      # (e.g., https://rapid.aaf.edu.au/jwt/authnrequest/auresearch/XXXXXXX)
      config.aaf[:redirect_url] = ENV.fetch('DF_AAF_UNIQUE_URL', nil)
      # URL of the identity provider (e.g., https://unifoo.edu.au/idp/shibboleth)
      config.aaf[:identity_provider_url] = ENV.fetch('DF_AAF_IDENTITY_PROVIDER_URL', nil)
      # The URL to redirect to after a signout
      config.aaf[:auth_signout_url] = ENV.fetch('DF_AAF_AUTH_SIGNOUT_URL', nil)
      # Redirection URL to use on front-end
      config.aaf[:redirect_url] += "?entityID=#{config.aaf[:identity_provider_url]}"
      # Check we have all values
      if config.aaf[:audience_url].nil? ||
         config.aaf[:callback_url].nil? ||
         config.aaf[:redirect_url].nil? ||
         config.aaf[:identity_provider_url].nil?
        raise "Invalid values specified to AAF, check the following environment variables: \n  " \
              "key                          => variable set?\n  " \
              "DF_AAF_ISSUER_URL            => #{!ENV['DF_AAF_ISSUER_URL'].nil?}\n  " \
              "DF_AAF_AUDIENCE_URL          => #{!ENV['DF_AAF_AUDIENCE_URL'].nil?}\n  " \
              "DF_AAF_CALLBACK_URL          => #{!ENV['DF_AAF_CALLBACK_URL'].nil?}\n  " \
              "DF_AAF_IDENTITY_PROVIDER_URL => #{!ENV['DF_AAF_IDENTITY_PROVIDER_URL'].nil?}\n  " \
              "DF_AAF_UNIQUE_URL            => #{!ENV['DF_AAF_UNIQUE_URL'].nil?}\n  " \
              "DF_SECRET_KEY_AAF            => #{!credentials.secret_key_aaf.nil?}\n"
      end
    end
    # Check secrets set for DF_SECRET_KEY_BASE, DF_SECRET_KEY_ATTR, DF_SECRET_KEY_DEVISE
    if credentials.secret_key_base.nil? ||
       credentials.secret_key_attr.nil? ||
       credentials.secret_key_devise.nil?
      raise "Required keys are not set, check the following environment variables: \n  " \
            "key                          => variable set?\n  " \
            "DF_SECRET_KEY_BASE           => #{!credentials.secret_key_base.nil?}\n  " \
            "DF_SECRET_KEY_ATTR           => #{!credentials.secret_key_base.nil?}\n  " \
            "DF_SECRET_KEY_DEVISE         => #{!credentials.secret_key_base.nil?}"
    end

    # Localization
    config.i18n.enforce_available_locales = true
    # Ensure that auth tokens do not appear in log files
    config.filter_parameters += %i(
      auth_token
      password
      password_confirmation
    )
    # Grape Serialization

    # config.paths.add 'app/api', glob: '**/*.rb'
    # config.autoload_paths += Dir["#{Rails.root}/app"]
    # config.autoload_paths += Dir[Rails.root.join("app", "models", "{*/}")]

    config.autoload_paths <<
      Rails.root.join('app') <<
      Rails.root.join('app/models/comments') <<
      Rails.root.join('app/models/communication') <<
      Rails.root.join('app/models/turn_it_in') <<
      Rails.root.join('app/models/similarity') <<
      Rails.root.join('app/models/d2l')

    config.eager_load_paths <<
      Rails.root.join('app') <<
      Rails.root.join('app/models/comments') <<
      Rails.root.join('app/models/communication') <<
      Rails.root.join('app/models/turn_it_in') <<
      Rails.root.join('app/models/similarity') <<
      Rails.root.join('app/models/d2l')

    # CORS config
    config.middleware.insert_before Warden::Manager, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: %i(get post put delete options)
      end
    end

    config.active_support.to_time_preserves_timezone = :zone

    # Generators for test framework
    if Rails.env.test?
      config.generators do |g|
        g.test_framework :minitest,
                         fixtures: true,
                         view_specs: false,
                         helper_specs: false,
                         routing_specs: false,
                         controller_specs: true,
                         request_specs: true
      end
    end

    config.sm_instance = nil
    config.overseer_enabled = ENV['OVERSEER_ENABLED'].present? && ENV['OVERSEER_ENABLED'].to_s.downcase != "false" && ENV['OVERSEER_ENABLED'].to_i != 0

    config.docker_config = {
      DOCKER_REGISTRY_URL: ENV.fetch('DOCKER_REGISTRY_URL', nil),
      DOCKER_PROXY_URL: ENV.fetch('DOCKER_PROXY_URL', nil),
      DOCKER_TOKEN: ENV.fetch('DOCKER_TOKEN', nil),
      DOCKER_USER: ENV.fetch('DOCKER_USER', nil)
    }

    if (config.overseer_enabled)
      # Path to a physical directory on the host used for mounting overseer task work directories.
      #
      # Example (macOS development):
      #   OVERSEER_WORKDIR_VOLUME_MOUNT=/Users/<name>/Dev/doubtfire-deploy/doubtfire-api/tmp/overseer
      #
      # This must point to a real location on your disk or server.
      # In production, mount a persistent host directory to the container, e.g.:
      #   /var/lib/doubtfire/overseer:/app/tmp/overseer
      # Then set:
      #   OVERSEER_WORKDIR_VOLUME_MOUNT=/var/lib/doubtfire/overseer
      config.overseer_workdir_volume_mount = ENV.fetch('OVERSEER_WORKDIR_VOLUME_MOUNT', nil)

      # Optional fallback for when a physical mount cannot be used.
      #
      # You can define a shared container in docker-compose, e.g.:
      #
      # overseer-volumes:
      #   container_name: doubtfire-overseer
      #   image: alpine
      #   command: sleep infinity
      #   volumes:
      #     - ../doubtfire-api/tmp/overseer:/overseer/work-dir
      #
      # Warning: this exposes the entire overseer directory to all overseer containers.
      # A malicious script could potentially delete or corrupt other running overseer jobs.
      #
      # This setup is the default for development to avoid requiring a mount,
      # but it is strongly recommended to leave this nil and use OVERSEER_WORKDIR_VOLUME_MOUNT instead.
      config.overseer_fallback_volume_container = ENV.fetch('OVERSEER_FALLBACK_VOLUME_CONTAINER', nil)

      if config.overseer_workdir_volume_mount.nil? && config.overseer_fallback_volume_container.nil?
        raise 'Overseer configuration error: you must set either OVERSEER_WORKDIR_VOLUME_MOUNT or OVERSEER_FALLBACK_VOLUME_CONTAINER.'
      end

      # Enables the endpoint to return how much available storage is left on the device the API is hosted on (often docker volume storage)
      # Used to ensure enough space is available to pull new images for Overseer
      config.disk_space_endpoint_enabled = %w[true 1 yes].include?(ENV['DISK_SPACE_ENDPOINT_ENABLED']&.downcase)

      config.after_initialize do
        if config.docker_config[:DOCKER_TOKEN] && config.docker_config[:DOCKER_PROXY_URL]
          LoginDockerJob.perform_async
        end
      end

    end
  end
end
