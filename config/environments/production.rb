# Settings specified here will take precedence over those in config/application.rb
Doubtfire::Application.configure do
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Use Redis for the shared production cache when configured. Falling back to
  # an in-process cache avoids FileStore races during concurrent expiry while
  # keeping production bootable for deployments without Redis.
  config.cache_store = if ENV['DF_REDIS_CACHE_URL'].present?
                         [:redis_cache_store, {
                           url: ENV.fetch('DF_REDIS_CACHE_URL'),
                           connect_timeout: 1,
                           read_timeout: 1,
                           write_timeout: 1
                         }]
                       else
                         :memory_store
                       end

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
      enable_starttls_auto: ENV.fetch('DF_SMTP_ENABLE_STARTTLS_AUTO', 'true') == 'true'
    }

    # reset authentication to nil if it is set to 'no_auth' or 'none'
    config.action_mailer.smtp_settings[:authentication] = nil if %w[no_auth none].include?(config.action_mailer.smtp_settings[:authentication])
  end

  config.active_record.encryption.key_derivation_salt = Doubtfire::Application.fetch_credential_or_env(:active_record_encryption, :key_derivation_salt, env_key: 'DF_ENCRYPTION_KEY_DERIVATION_SALT')
  config.active_record.encryption.deterministic_key = Doubtfire::Application.fetch_credential_or_env(:active_record_encryption, :deterministic_key, env_key: 'DF_ENCRYPTION_DETERMINISTIC_KEY')
  config.active_record.encryption.primary_key = Doubtfire::Application.fetch_credential_or_env(:active_record_encryption, :primary_key, env_key: 'DF_ENCRYPTION_PRIMARY_KEY')
end
