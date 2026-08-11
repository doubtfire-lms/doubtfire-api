require 'rest-client'
require 'uri'

class SentryTunnelMiddleware
  PATH = '/api/client-reports'.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env['REQUEST_METHOD'] == 'POST' && env['PATH_INFO'] == PATH

    forward_envelope(env)
    [204, {}, []]
  end

  private

  def forward_envelope(env)
    envelope_url = sentry_envelope_url
    return if envelope_url.blank?

    body = env['rack.input'].read
    return if body.blank?

    RestClient::Request.execute(
      method: :post,
      url: envelope_url,
      payload: body,
      headers: sentry_headers(env),
      timeout: 5,
      open_timeout: 2
    )
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.warn "Unable to forward Sentry envelope: #{e.class} #{e.response&.code}"
  rescue RestClient::Exception, SocketError, Timeout::Error => e
    Rails.logger.warn "Unable to forward Sentry envelope: #{e.class}"
  ensure
    env['rack.input'].rewind if env['rack.input'].respond_to?(:rewind)
  end

  def sentry_headers(env)
    headers = {
      content_type: env['CONTENT_TYPE'].presence || 'application/x-sentry-envelope'
    }

    headers[:content_encoding] = env['HTTP_CONTENT_ENCODING'] if env['HTTP_CONTENT_ENCODING'].present?
    headers
  end

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
