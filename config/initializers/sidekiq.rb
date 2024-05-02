Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('DF_REDIS_SIDEKIQ_URL', 'redis://localhost:6379/1') }
  config.logger = Rails.logger
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('DF_REDIS_SIDEKIQ_URL', 'redis://localhost:6379/1') }
  config.logger = Rails.logger
end
