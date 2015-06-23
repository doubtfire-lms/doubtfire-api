require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'csv'
require 'grape-active_model_serializers'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(assets:  %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module Doubtfire
  class Application < Rails::Application
    
    # Ensure that auth tokens do not appear in log files
    config.filter_parameters += [:auth_token, :password, :password_confirmation, :credit_card]

    config.i18n.enforce_available_locales = true

    config.paths.add "app/api", glob: "**/*.rb"             #For Grape
    config.autoload_paths += Dir["#{Rails.root}/app"]       # For Grape
    config.autoload_paths += Dir["#{Rails.root}/app/serializers"]

    config.middleware.insert_before Warden::Manager, Rack::Cors do
      allow do
        origins '*'
        resource '*',
        :headers => :any,
        :methods => [:get, :post, :put, :delete, :options]
      end
    end

    config.generators do |g|
      g.test_framework :rspec,
        fixtures: true,
        view_specs: false,
        helper_specs: false,
        routing_specs: false,
        controller_specs: true,
        request_specs: true
      g.fixture_replacement :factory_girl, dir: "spec/factories"
    end
  end
end
