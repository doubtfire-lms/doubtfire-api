require 'rest-client'
require 'uri'

class SentryTunnelController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    envelope_url = sentry_envelope_url
    return head :no_content if envelope_url.blank?

    body = request.raw_post
    return head :no_content if body.blank?

    RestClient::Request.execute(
      method: :post,
      url: envelope_url,
      payload: body,
      headers: { content_type: request.content_type || 'application/x-sentry-envelope' },
      timeout: 5,
      open_timeout: 2
    )

    head :no_content
  rescue RestClient::Exception, SocketError, Timeout::Error => e
    Rails.logger.warn "Unable to forward Sentry envelope: #{e.class}"
    head :no_content
  end

  private

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
