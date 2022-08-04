# Settings specified here will take precedence over those in config/application.rb
Doubtfire::Application.configure do
  # Code is not reloaded between requests
  config.cache_classes = true

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

  require_relative 'doubtfire_logger'
  config.logger = DoubtfireLogger.logger
  Rails.logger = DoubtfireLogger.logger
  config.log_level = :info

  config.action_mailer.perform_deliveries = (ENV['DF_MAIL_PERFORM_DELIVERIES'] || 'yes') == 'yes'
  config.action_mailer.delivery_method = (ENV['DF_MAIL_DELIVERY_METHOD'] || 'smtp').to_sym

  if config.action_mailer.delivery_method == :smtp
    config.action_mailer.smtp_settings = {
      address: (ENV['DF_SMTP_ADDRESS'] || 'localhost'),
      port: (ENV['DF_SMTP_PORT'] || 25),
      domain: (ENV['DF_SMTP_DOMAIN']),
      user_name: (ENV['DF_SMTP_USERNAME']),
      password: (ENV['DF_SMTP_PASSWORD']),
      authentication: (ENV['DF_SMTP_AUTHENTICATION'] || 'plain'),
      enable_starttls_auto: true
    }
  end

  config.active_record.encryption.key_derivation_salt = ENV['DF_ENCRYPTION_KEY_DERIVATION_SALT']
  config.active_record.encryption.deterministic_key = ENV['DF_ENCRYPTION_DETERMINISTIC_KEY']
  config.active_record.encryption.primary_key = ENV['DF_ENCRYPTION_PRIMARY_KEY']
end
