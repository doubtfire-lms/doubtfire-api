# Settings specified here will take precedence over those in config/application.rb
Doubtfire::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Eager loading on models
  config.eager_load = false

  # Show full error reports and disable caching
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Ensure cache is cleared on reload
  unless Rails.application.config.cache_classes
    Rails.autoloaders.main.on_unload do |klass, _abspath|
      Rails.cache.clear
    end
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # Write them to file instead (under doubtfire-api/tmp/mails)
  config.action_mailer.delivery_method = :file

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  config.action_controller.perform_caching = false

  # Logging level (:debug, :info, :warn, :error, :fatal)
  config.log_level = :debug

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Set deterministic randomness, source: https://github.com/stympy/faker#deterministic-random
  Faker::Config.random = Random.new(77)

  # pdfgen log verbosity
  config.pdfgen_quiet = false

  require_relative 'doubtfire_logger'
  config.logger = DoubtfireLogger.logger
  Rails.logger = DoubtfireLogger.logger

  config.active_record.encryption.key_derivation_salt = ENV['DF_ENCRYPTION_KEY_DERIVATION_SALT'] || 'U9jurHMfZbMpzlbDTMe5OSAhUJYHla9Z'
  config.active_record.encryption.deterministic_key = ENV['DF_ENCRYPTION_DETERMINISTIC_KEY'] || 'zYtzYUlLFaWdvdUO5eIINRT6ZKDddcgx'
  config.active_record.encryption.primary_key = ENV['DF_ENCRYPTION_PRIMARY_KEY'] || '92zoF7RJaQ01JEExOgHbP9bRWldNQUz5'
end
