module Rack
  class Attack
    # Production uses the configured Rails cache: Redis when available,
    # otherwise an in-process memory store.
    Rack::Attack.cache.store = if Rails.env.production?
                                 Rails.cache
                               else
                                 ActiveSupport::Cache::MemoryStore.new
                               end

    # Limit repeated login attempts against the API auth endpoint.
    throttle('auth/ip', limit: Doubtfire::Application.config.auth_rate_limit,
                        period: Doubtfire::Application.config.auth_rate_period_seconds.seconds) do |req|
      req.ip if Doubtfire::Application.config.auth_rate_limit_enabled && req.path.start_with?('/api/auth') && req.post?
    end

    # Return a consistent API-friendly throttling response.
    self.throttled_responder = lambda do |request|
      rack_env =
        if request.respond_to?(:env)
          request.env
        elsif request.respond_to?(:[])
          request
        else
          {}
        end

      match_data = rack_env['rack.attack.match_data'] || {}
      now = match_data[:epoch_time] || Time.now.to_i
      retry_after = match_data[:period].to_i - (now % match_data[:period].to_i) if match_data[:period].to_i.positive?

      body = { error: 'Too many login attempts. Please try again shortly.' }.to_json
      headers = { 'Content-Type' => 'application/json' }
      headers['Retry-After'] = retry_after.to_s if retry_after

      [429, headers, [body]]
    end
  end
end
