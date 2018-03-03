# Settings specified here will take precedence over those in config/application.rb
require_relative 'production'
Doubtfire::Application.configure do
  # Staging uses production configuration, with minor changes to logging
  # levels for extra information
  config.log_level = :info
  config.force_ssl = false
end
