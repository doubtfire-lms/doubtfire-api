# Settings specified here will take precedence over those in config/application.rb
Doubtfire::Application.configure do
  # Show full error reports and disable caching
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  # Raise errors if the mailer can't send
  config.action_mailer.raise_delivery_errors = true

  # Tell Action Mailer not to deliver emails to the real world.
  # Write them to file instead (under doubtfire-api/tmp/mails)
  config.action_mailer.delivery_method = :file

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Logging level (:debug, :info, :warn, :error, :fatal)
  config.log_level = :info

  # Eager loading on models
  config.eager_load = false

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = true

  # TODO: Remove the if check here
  # Use the doubtfire logger instead of the default one
  if Rails.env.development?
    require 'doubtfire_logger'
    config.logger = DoubtfireLogger.logger
  end

  # Set deterministic randomness, source: https://github.com/stympy/faker#deterministic-random
  Faker::Config.random = Random.new(77)
end
