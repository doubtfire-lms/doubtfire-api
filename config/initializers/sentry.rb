if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV.fetch("SENTRY_DSN", nil)
    # get breadcrumbs from logs
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    config.release = ENV["SENTRY_RELEASE"] if ENV["SENTRY_RELEASE"].present?
    # Add data like request headers and IP for users, if applicable;
    # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
    config.send_default_pii = false
  end
end
