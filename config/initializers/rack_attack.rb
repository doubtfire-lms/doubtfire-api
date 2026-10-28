require 'digest'

module Rack
  class Attack
    AUTH_REFRESH_PATHS = %w[/api/auth/access-token /api/auth/access-token.json].freeze

    # Production uses the configured Rails cache: Redis when available,
    # otherwise an in-process memory store.
    Rack::Attack.cache.store = if Rails.env.production?
                                 Rails.cache
                               else
                                 ActiveSupport::Cache::MemoryStore.new
                               end

    # Limit repeated login attempts without counting routine access-token refreshes.
    throttle('auth/ip', limit: Doubtfire::Application.config.auth_rate_limit,
                        period: Doubtfire::Application.config.auth_rate_period_seconds.seconds) do |req|
      next unless Doubtfire::Application.config.auth_rate_limit_enabled && req.post? && req.path.start_with?('/api/auth')
      next if AUTH_REFRESH_PATHS.include?(req.path)

      req.ip
    end

    # Limit repeated use of one refresh cookie without affecting other users of a shared IP.
    throttle('auth/refresh/token', limit: Doubtfire::Application.config.auth_refresh_rate_limit,
                                   period: Doubtfire::Application.config.auth_refresh_rate_period_seconds.seconds) do |req|
      next unless Doubtfire::Application.config.auth_rate_limit_enabled && req.post? && AUTH_REFRESH_PATHS.include?(req.path)

      refresh_token = req.cookies['refresh_token']
      next if refresh_token.blank? || refresh_token.bytesize > 256

      Digest::SHA256.hexdigest(refresh_token)
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

      message = if AUTH_REFRESH_PATHS.include?(rack_env['PATH_INFO'])
                  'Too many token refresh attempts. Please try again shortly.'
                else
                  'Too many login attempts. Please try again shortly.'
                end
      body = { error: message }.to_json
      headers = { 'Content-Type' => 'application/json' }
      headers['Retry-After'] = retry_after.to_s if retry_after

      [429, headers, [body]]
    end
  end
end
