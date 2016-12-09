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
    # Localization
    config.i18n.enforce_available_locales = true
    # Institution load
    config.institution = YAML.load_file("#{Rails.root}/config/institution.yml").with_indifferent_access
    # Ensure that auth tokens do not appear in log files
    config.filter_parameters += %i(
      auth_token
      password
      password_confirmation
      credit_card
    )
    # Grape Serialization
    config.paths.add 'app/api', glob: '**/*.rb'
    config.autoload_paths += Dir["#{Rails.root}/app"]
    config.autoload_paths += Dir["#{Rails.root}/app/serializers"]
    # CORS congig
    config.middleware.insert_before Warden::Manager, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: %i(get post put delete options)
      end
    end
    # Generators for test framework
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
