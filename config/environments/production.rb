# Settings specified here will take precedence over those in config/application.rb
Doubtfire::Application.configure do
  # Code is not reloaded between requests
  config.cache_classes = true
  config.cache_store = :redis_cache_store, { url: ENV.fetch('DF_REDIS_CACHE_URL', 'redis://localhost:6379/0'),

    connect_timeout:    30,  # Defaults to 1 second
    read_timeout:       0.2, # Defaults to 1 second
    write_timeout:      0.2, # Defaults to 1 second
    reconnect_attempts: 2,   # Defaults to 1

    error_handler: lambda { |method:, returning:, exception:|
      # Report errors to Sentry as warnings
      Sentry.capture_exception exception, level: 'warning',
        tags: { method: method, returning: returning }
    } }

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_files = true

  # Eager loading on models
  config.eager_load = true

  # Prevent too many redirects issue if SSL handled elsewhere
  config.force_ssl = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Remove the Runtime middleware which is responsible for inserting the X-Runtime header
  # to harden the application against timing attacks and unauthenticated object enumeration
  config.middleware.delete Rack::Runtime

  # pdfgen log verbosity
  config.pdfgen_quiet = true

  config.log_level = :info

  config.action_mailer.perform_deliveries = (ENV['DF_MAIL_PERFORM_DELIVERIES'] || 'yes') == 'yes'
  config.action_mailer.delivery_method = (ENV['DF_MAIL_DELIVERY_METHOD'] || 'smtp').to_sym

  if config.action_mailer.delivery_method == :smtp
    config.action_mailer.smtp_settings = {
      address: ENV.fetch('DF_SMTP_ADDRESS', 'localhost'),
      port: ENV.fetch('DF_SMTP_PORT', 25),
      domain: ENV.fetch('DF_SMTP_DOMAIN', nil),
      user_name: ENV.fetch('DF_SMTP_USERNAME', nil),
      password: ENV.fetch('DF_SMTP_PASSWORD', nil),
      authentication: ENV.fetch('DF_SMTP_AUTHENTICATION', 'plain'),
      enable_starttls_auto: true
    }
  end

  config.active_record.encryption.key_derivation_salt = ENV.fetch('DF_ENCRYPTION_KEY_DERIVATION_SALT', nil)
  config.active_record.encryption.deterministic_key = ENV.fetch('DF_ENCRYPTION_DETERMINISTIC_KEY', nil)
  config.active_record.encryption.primary_key = ENV.fetch('DF_ENCRYPTION_PRIMARY_KEY', nil)
end
