require File.expand_path('../boot', __FILE__)
require 'rails/all'
require 'csv'
require 'yaml'
require 'grape-active_model_serializers'

# Precompile assets before deploying to production
if defined?(Bundler)
  Bundler.require(*Rails.groups(assets: %w(development test)))
end

module Doubtfire
  #
  # Doubtfire generic application configuration
  #
  class Application < Rails::Application
    # Load .env variables
    Dotenv::Railtie.load

    # ==> Authentication Method
    # Authentication method default is database, but possible settings
    # are: database, ldap, aaf. It can be overridden using the DF_AUTH_METHOD
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
    
    require "#{Rails.root}/config/#{config.institution[:settings]}" unless config.institution[:settings].nil?

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
    # Localization
    config.i18n.enforce_available_locales = true
    # Ensure that auth tokens do not appear in log files
    config.filter_parameters += %i(
      auth_token
      password
      password_confirmation
    )
    # Grape Serialization
    config.paths.add 'app/api', glob: '**/*.rb'
    config.autoload_paths += Dir["#{Rails.root}/app"]
    config.autoload_paths += Dir["#{Rails.root}/app/serializers"]
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
  end
end
