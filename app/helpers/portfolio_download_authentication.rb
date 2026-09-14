module PortfolioDownloadAuthentication
  PORTFOLIO_DOWNLOAD_COOKIE = 'ontrack_portfolio_download'.freeze
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

  # Valid for its whole lifetime, not single-use: browsers resume an interrupted
  # download by re-requesting the same URL.
  def portfolio_download_cookie_user(unit_id:)
    payload = JSON.parse(cookies.encrypted[PORTFOLIO_DOWNLOAD_COOKIE].to_s)
    return unless payload['unit_id'].to_s == unit_id.to_s
    return unless payload['expires_at'].to_i > Time.current.to_i

    User.find_by(id: payload['user_id'])
  rescue JSON::ParserError
    nil
  end
end
