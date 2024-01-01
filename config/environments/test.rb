# Settings specified here will take precedence over those in config/application.rb
Doubtfire::Application.configure do
  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Configure static asset server for tests with Cache-Control for performance
  config.serve_static_files = true
  config.static_cache_control = 'public, max-age=3600'

  # Eager
  config.eager_load = false

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  # Set deterministic randomness, source: https://github.com/stympy/faker#deterministic-random
  Faker::Config.random = Random.new(77)

  # Logging level (:debug, :info, :warn, :error, :fatal)
  config.log_level = :warn

  config.active_record.encryption.key_derivation_salt = ENV['DF_ENCRYPTION_KEY_DERIVATION_SALT'] || 'U9jurHMfZbMpzlbDTMe5OSAhUJYHla9Z'
  config.active_record.encryption.deterministic_key = ENV['DF_ENCRYPTION_KEY_DERIVATION_SALT'] || 'zYtzYUlLFaWdvdUO5eIINRT6ZKDddcgx'
  config.active_record.encryption.primary_key = ENV['DF_ENCRYPTION_KEY_DERIVATION_SALT'] || '92zoF7RJaQ01JEExOgHbP9bRWldNQUz5'

  # Set turn it in environment
  ENV.store('TCA_SIGNING_KEY', 'test')
  ENV.store('TII_ENABLED', '1')
  ENV.store('TCA_API_KEY', '1234')
  ENV.store('TCA_HOST', 'localhost')
end
