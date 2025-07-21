Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('DF_REDIS_SIDEKIQ_URL', 'redis://localhost:6379/1') }
  config.logger = Rails.logger

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  SidekiqUniqueJobs::Server.configure(config)

  Sidekiq::Status.configure_server_middleware(config, expiration: 30.minutes.to_i)
  Sidekiq::Status.configure_client_middleware(config, expiration: 30.minutes.to_i)
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('DF_REDIS_SIDEKIQ_URL', 'redis://localhost:6379/1') }
  config.logger = Rails.logger

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  Sidekiq::Status.configure_client_middleware(config, expiration: 30.minutes.to_i)
end
