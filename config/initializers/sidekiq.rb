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

  config.on(:startup) do
    schedule_file = Rails.root.join('config/schedule.yml')
    Sidekiq::Cron::Job.load_from_hash!(YAML.load_file(schedule_file)) if File.exist?(schedule_file)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('DF_REDIS_SIDEKIQ_URL', 'redis://localhost:6379/1') }
  config.logger = Rails.logger

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  Sidekiq::Status.configure_client_middleware(config, expiration: 30.minutes.to_i)
end
