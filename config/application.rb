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

    # Load .env variables
    Dotenv::Railtie.load

    # ==> Authentication Method
    # Authentication method default is database, but possible settings
    # are: database, ldap, aaf, or saml. It can be overridden using the DF_AUTH_METHOD
    # environment variable.
    config.auth_method = (ENV['DF_AUTH_METHOD'] || :database).to_sym

    # ==> Student work directory
    # File server location for storing student's work. Defaults to `student_work`
    # directory under root but is overridden using DF_STUDENT_WORK_DIR environment
    # variable.
    config.student_work_dir = ENV['DF_STUDENT_WORK_DIR'] || "#{Rails.root}/student_work"

    # ==> Institution settings
    # Institution YAML and ENV (override) config load
    config.institution = YAML.load_file("#{Rails.root}/config/institution.yml").with_indifferent_access
    config.institution[:name] = ENV['DF_INSTITUTION_NAME'] if ENV['DF_INSTITUTION_NAME']
    config.institution[:email_domain] = ENV['DF_INSTITUTION_EMAIL_DOMAIN'] if ENV['DF_INSTITUTION_EMAIL_DOMAIN']
    config.institution[:host] = ENV['DF_INSTITUTION_HOST'] if ENV['DF_INSTITUTION_HOST']
    config.institution[:product_name] = ENV['DF_INSTITUTION_PRODUCT_NAME'] if ENV['DF_INSTITUTION_PRODUCT_NAME']
    config.institution[:privacy] = ENV['DF_INSTITUTION_PRIVACY'] if ENV['DF_INSTITUTION_PRIVACY']
    config.institution[:plagiarism] = ENV['DF_INSTITUTION_PLAGIARISM'] if ENV['DF_INSTITUTION_PLAGIARISM']
    # Institution host becomes localhost in all but prod
    config.institution[:host] = 'localhost:3000' if Rails.env.development?
    config.institution[:host_url] = Rails.env.development? ? "http://#{config.institution[:host]}/" : "https://#{config.institution[:host]}/"
    config.institution[:settings] = ENV['DF_INSTITUTION_SETTINGS_RB'] if ENV['DF_INSTITUTION_SETTINGS_RB']
    config.institution[:ffmpeg] = ENV['DF_FFMPEG_PATH'] || 'ffmpeg'

    require "#{Rails.root}/config/#{config.institution[:settings]}" unless config.institution[:settings].nil?

    # ==> SAML2.0 authentication
    if config.auth_method == :saml
      config.saml = HashWithIndifferentAccess.new
      # URL of the XML SAML Metadata (if available).
      config.saml[:SAML_metadata_url] = ENV['DF_SAML_METADATA_URL']
      # URL to return the SAML response to (e.g., 'https://doubtfire.edu/api/auth/jwt'
      config.saml[:assertion_consumer_service_url] = ENV['DF_SAML_CONSUMER_SERVICE_URL']
      # URL of the registered application (e.g., https://doubtfire.unifoo.edu.au)
      config.saml[:entity_id] = ENV['DF_SAML_SP_ENTITY_ID']
      # The IDP SAML login URL, (e.g., "https://login.microsoftonline.com/xxxx/saml2")
      config.saml[:idp_sso_target_url] = ENV['DF_SAML_IDP_TARGET_URL']
      # The IDP SAML logout URL, (e.g., "https://login.microsoftonline.com/xxxx/saml2")
      config.saml[:idp_sso_signout_url] = ENV['DF_SAML_IDP_SIGNOUT_URL']

      # The SAML response certificate and name format (if no XML URL metadata is provided)
      if config.saml[:SAML_metadata_url].nil?
        config.saml[:idp_sso_cert] = ENV['DF_SAML_IDP_CERT']

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
        raise "Invalid values specified to saml, check the following environment variables: \n"\
        "  key                          => variable set?\n"\
        "  DF_SAML_CONSUMER_SERVICE_URL            => #{!ENV['DF_SAML_CONSUMER_SERVICE_URL'].nil?}\n"\
        "  DF_SAML_SP_ENTITY_ID          => #{!ENV['DF_SAML_SP_ENTITY_ID'].nil?}\n"\
        "  DF_SAML_IDP_SIGNOUT_URL         => #{!ENV['DF_SAML_IDP_SIGNOUT_URL'].nil?}\n"\
        "  DF_SAML_IDP_TARGET_URL          => #{!ENV['DF_SAML_IDP_TARGET_URL'].nil?}\n"
      end

      # If there's no XML url, we need the cert
      if config.saml[:SAML_metadata_url].nil? &&
         config.saml[:idp_sso_cert].nil?
        raise "Missing IDP certificate for SAML config: \n"
      end
    end

    # ==> AAF authentication
    # Must require AAF devise authentication method.
    if config.auth_method == :aaf
      config.aaf = HashWithIndifferentAccess.new
      # URL of the issuer (i.e., https://rapid.[test.]aaf.edu.au)
      config.aaf[:issuer_url] = ENV['DF_AAF_ISSUER_URL'] || 'https://rapid.test.aaf.edu.au'
      # URL of the registered application (e.g., https://doubtfire.unifoo.edu.au)
      config.aaf[:audience_url] = ENV['DF_AAF_AUDIENCE_URL']
      # The secure URL within your application that AAF Rapid Connect should
      # POST responses to (e.g., https://doubtfire.unifoo.edu.au/auth/jwt)
      config.aaf[:callback_url] = ENV['DF_AAF_CALLBACK_URL']
      # URL of the unique url provided by rapid connect used for redirect
      # (e.g., https://rapid.aaf.edu.au/jwt/authnrequest/auresearch/XXXXXXX)
      config.aaf[:redirect_url] = ENV['DF_AAF_UNIQUE_URL']
      # URL of the identity provider (e.g., https://unifoo.edu.au/idp/shibboleth)
      config.aaf[:identity_provider_url] = ENV['DF_AAF_IDENTITY_PROVIDER_URL']
      # The URL to redirect to after a signout
      config.aaf[:auth_signout_url] = ENV['DF_AAF_AUTH_SIGNOUT_URL']
      # Redirection URL to use on front-end
      config.aaf[:redirect_url] += "?entityID=#{config.aaf[:identity_provider_url]}"
      # Check we have all values
      if config.aaf[:audience_url].nil? ||
         config.aaf[:callback_url].nil? ||
         config.aaf[:redirect_url].nil? ||
         config.aaf[:identity_provider_url].nil?
        raise "Invalid values specified to AAF, check the following environment variables: \n"\
              "  key                          => variable set?\n"\
              "  DF_AAF_ISSUER_URL            => #{!ENV['DF_AAF_ISSUER_URL'].nil?}\n"\
              "  DF_AAF_AUDIENCE_URL          => #{!ENV['DF_AAF_AUDIENCE_URL'].nil?}\n"\
              "  DF_AAF_CALLBACK_URL          => #{!ENV['DF_AAF_CALLBACK_URL'].nil?}\n"\
              "  DF_AAF_IDENTITY_PROVIDER_URL => #{!ENV['DF_AAF_IDENTITY_PROVIDER_URL'].nil?}\n"\
              "  DF_AAF_UNIQUE_URL            => #{!ENV['DF_AAF_UNIQUE_URL'].nil?}\n"\
              "  DF_SECRET_KEY_AAF            => #{!secrets.secret_key_aaf.nil?}\n"
      end
    end
    # Check secrets set for DF_SECRET_KEY_BASE, DF_SECRET_KEY_ATTR, DF_SECRET_KEY_DEVISE
    if secrets.secret_key_base.nil? ||
       secrets.secret_key_attr.nil? ||
       secrets.secret_key_devise.nil?
      raise "Required keys are not set, check the following environment variables: \n"\
            "  key                          => variable set?\n"\
            "  DF_SECRET_KEY_BASE           => #{!secrets.secret_key_base.nil?}\n"\
            "  DF_SECRET_KEY_ATTR           => #{!secrets.secret_key_base.nil?}\n"\
            "  DF_SECRET_KEY_DEVISE         => #{!secrets.secret_key_base.nil?}"
    end

    config.active_record.legacy_connection_handling = false

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
    config.eager_load_paths << Rails.root.join('app') << Rails.root.join('app', 'models', 'comments')

    # CORS config
    config.middleware.insert_before Warden::Manager, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: %i(get post put delete options)
      end
    end
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
    config.overseer_enabled = ENV['OVERSEER_ENABLED'].present? && ENV['OVERSEER_ENABLED'].to_s.downcase != "false" && ENV['OVERSEER_ENABLED'].to_i != 0 ? true : false

    if (config.overseer_enabled)
      config.overseer_images = YAML.load_file(Rails.root.join('config/overseer-images.yml')).with_indifferent_access
      config.has_overseer_image = ->(key) { config.overseer_images['images'].any? { |img| img[:name] == key } }

      docker_config = {
        DOCKER_PROXY_URL: ENV['DOCKER_PROXY_URL'],
        DOCKER_TOKEN: ENV['DOCKER_TOKEN'],
        DOCKER_USER: ENV['DOCKER_USER']
      }

      publisher_config = {
        RABBITMQ_HOSTNAME: ENV['RABBITMQ_HOSTNAME'],
        RABBITMQ_USERNAME: ENV['RABBITMQ_USERNAME'],
        RABBITMQ_PASSWORD: ENV['RABBITMQ_PASSWORD'],
        EXCHANGE_NAME: 'ontrack',
        DURABLE_QUEUE_NAME: 'q.tasks',
        # Publisher specific key -- all publishers will post task submissions with this key
        ROUTING_KEY: 'task.submission'
      }

      subscriber_config = {
        RABBITMQ_HOSTNAME: ENV['RABBITMQ_HOSTNAME'],
        RABBITMQ_USERNAME: ENV['RABBITMQ_USERNAME'],
        RABBITMQ_PASSWORD: ENV['RABBITMQ_PASSWORD'],
        EXCHANGE_NAME: 'ontrack',
        DURABLE_QUEUE_NAME: 'q.overseer',
        # No need to define BINDING_KEYS for now!
        # In future, OnTrack will listen to
        # topics related to PDF generation too.
        # That is when we should have BINDING_KEYS defined.
        # BINDING_KEYS: ENV['BINDING_KEYS'],

        # This is enough for now:
        DEFAULT_BINDING_KEY: '*.result'
      }

      if docker_config[:DOCKER_TOKEN] && docker_config[:DOCKER_PROXY_URL]
        puts "Logging into docker proxy"
        `echo \"${DOCKER_TOKEN}\" | docker login --username ${DOCKER_USER} --password-stdin ${DOCKER_PROXY_URL}`
      end

      config.sm_instance = ServicesManager.instance
      config.sm_instance.register_client(:ontrack, publisher_config, subscriber_config)
    end
  end
end
