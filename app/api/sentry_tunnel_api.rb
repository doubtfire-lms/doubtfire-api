require 'grape'
require 'rest-client'
require 'uri'

class SentryTunnelApi < Grape::API
  helpers do
    def sentry_envelope_url
      dsn = ENV.fetch('SENTRY_DSN', nil)
      return nil if dsn.blank?

      uri = URI.parse(dsn)
      project_id = uri.path.delete_prefix('/')
      public_key = uri.user
      return nil if project_id.blank? || public_key.blank?

      "#{uri.scheme}://#{uri.host}/api/#{project_id}/envelope/?sentry_key=#{URI.encode_www_form_component(public_key)}"
    rescue URI::InvalidURIError
      nil
    end
  end

  desc 'Forward browser Sentry envelopes to Sentry'
  post '/sentry/tunnel' do
    envelope_url = sentry_envelope_url
    status 204
    return if envelope_url.blank?

    body = request.body.read
    return if body.blank?

    RestClient::Request.execute(
      method: :post,
      url: envelope_url,
      payload: body,
      headers: { content_type: request.content_type || 'application/x-sentry-envelope' },
      timeout: 5,
      open_timeout: 2
    )

    nil
  rescue RestClient::Exception, SocketError, Timeout::Error => e
    logger.warn "Unable to forward Sentry envelope: #{e.class}"
    nil
  end
end
