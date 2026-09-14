module PortfolioDownloadAuthentication
  PORTFOLIO_DOWNLOAD_COOKIE = 'ontrack_portfolio_download'.freeze
  PORTFOLIO_DOWNLOAD_TICKET_SCOPE = 'portfolio'.freeze
  PORTFOLIO_DOWNLOAD_TICKET_ENV_KEY = 'ontrack.portfolio_download_ticket_nonce'.freeze
  PORTFOLIO_DOWNLOAD_COOKIE_LIFETIME = 30.seconds

  private

  def authenticated_portfolio_download_user(unit_id:)
    authenticated_portfolio_download_header_user || portfolio_download_cookie_user(unit_id: unit_id)
  end

  def authenticated_portfolio_download_header_user
    username, token = get_user_and_token_from(:header)
    return unless username.present? && token.present?
    return unless user_auth_token_type(username, token, :general) == :valid

    current_user
  end

  def portfolio_download_cookie_user(unit_id:)
    payload = JSON.parse(cookies.encrypted[PORTFOLIO_DOWNLOAD_COOKIE].to_s)
    return unless payload['unit_id'].to_s == unit_id.to_s
    return unless payload['expires_at'].to_i > Time.current.to_i

    nonce = payload['nonce'].presence
    return unless nonce

    request.env[PORTFOLIO_DOWNLOAD_TICKET_ENV_KEY] = nonce

    User.find_by(id: payload['user_id'])
  rescue JSON::ParserError
    nil
  end

  def consume_portfolio_download_ticket!(unit_id:)
    # Caddy rewrites the auth subrequest to GET but preserves the browser's
    # original method in this header. A HEAD probe must not burn the ticket
    # needed by the subsequent GET that actually transfers the file.
    original_method = request.headers['X-Forwarded-Method'].presence || request.request_method
    return true if original_method == 'HEAD'
    nonce = request.env[PORTFOLIO_DOWNLOAD_TICKET_ENV_KEY]
    return true unless nonce

    cookies.delete(
      PORTFOLIO_DOWNLOAD_COOKIE,
      domain: Doubtfire::Application.config.institution[:cookie_domain],
      path: "/api/submission/unit/#{unit_id}/portfolio",
      secure: request.ssl? || Rails.env.production?,
      httponly: true,
      same_site: :strict
    )
    OneTimeDownloadTicket.consume(
      scope: PORTFOLIO_DOWNLOAD_TICKET_SCOPE,
      nonce: nonce
    )
  end
end
