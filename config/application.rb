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
    # ==> Authentication Method
    # Authentication method default is database, but possible settings
    # are: database, ldap, aff. It can be overridden using the DF_DEVISE_AUTH_METHOD
    # environment variable.
    config.devise_auth_method = (ENV['DF_DEVISE_AUTH_METHOD'] || :database).to_sym
    # ==> Student work directory
    # File server location for storing student's work. Defaults to `student_work`
    # directory under root but is overridden using DF_STUDENT_WORK_DIR environment
    # variable.
    config.student_work_dir = ENV['DF_STUDENT_WORK_DIR'] || "#{Rails.root}/student_work"
    # ==> Institution settings
    # Institution YAML config load
    config.institution = YAML.load_file("#{Rails.root}/config/institution.yml").with_indifferent_access
    # Institution host becomes localhost in all but prod
    config.institution[:host] = 'localhost:3000' unless Rails.env.production?
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
