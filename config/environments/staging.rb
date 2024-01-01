# Settings specified here will take precedence over those in config/application.rb
require_relative 'production'
Doubtfire::Application.configure do
  # Staging uses production configuration, with minor changes to logging
  # levels for extra information
  config.force_ssl = false

  # Set deterministic randomness, source: https://github.com/stympy/faker#deterministic-random
  Faker::Config.random = Random.new(77)

  config.log_level = :info
end
