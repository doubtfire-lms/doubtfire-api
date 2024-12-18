# frozen_string_literal: true

require 'oauth2'

# Class to load d2l integration features
#
class D2lIntegration
  def self.enabled?
    Doubtfire::Application.config.d2l_enabled &&
      Doubtfire::Application.config.d2l_client_id.present? &&
      Doubtfire::Application.config.d2l_client_secret.present? &&
      Doubtfire::Application.config.d2l_redirect_uri.present?
  end

  def self.d2l_client_id
    Doubtfire::Application.config.d2l_client_id
  end

  def self.d2l_client_secret
    Doubtfire::Application.config.d2l_client_secret
  end

  def self.d2l_redirect_uri
    Doubtfire::Application.config.d2l_redirect_uri
  end

  def self.d2l_oauth_site
    Doubtfire::Application.config.d2l_oauth_site
  end

  def self.d2l_oauth_authorize_url
    Doubtfire::Application.config.d2l_oauth_authorize_url
  end

  def self.d2l_oauth_token_url
    Doubtfire::Application.config.d2l_oauth_token_url
  end

  def self.d2l_api_version
    Doubtfire::Application.config.d2l_api_version
  end

  def self.load_config(config)
    config.d2l_enabled = ENV['D2L_ENABLED'].present? && (ENV['D2L_ENABLED'].to_s.downcase == "true" || ENV['D2L_ENABLED'].to_i == 1)

    if config.d2l_enabled
      config.d2l_client_id = ENV.fetch('D2L_CLIENT_ID', nil)
      config.d2l_client_secret = ENV.fetch('D2L_CLIENT_SECRET', nil)
      config.d2l_redirect_uri = ENV.fetch('D2L_REDIRECT_URI', nil)
      config.d2l_oauth_site = ENV.fetch('D2L_OAUTH_SITE', nil)
      config.d2l_oauth_authorize_url = ENV.fetch('D2L_OAUTH_SITE_AUTHORIZE_URL', nil)
      config.d2l_oauth_token_url = ENV.fetch('D2L_OAUTH_SITE_TOKEN_URL', nil)
      config.d2l_api_version = ENV.fetch('D2L_API_VERSION', nil)
    end
  end

  def self.oauth_client
    return nil unless self.enabled?

    OAuth2::Client.new(
      self.d2l_client_id,
      self.d2l_client_secret,
      site: self.d2l_oauth_site,
      authorize_url: self.d2l_oauth_authorize_url,
      token_url: self.d2l_oauth_token_url
    )
  end

  def self.login_url(user)
    return nil unless self.enabled?

    # Create oauth client to initiate login
    client = self.oauth_client

    # Generate a random state, unique within the user_oauth_states table
    state = SecureRandom.hex(16)

    # Ensure state is unique
    i = 0
    state = SecureRandom.hex(16) until UserOauthState.create(state: state, user: user) || ++i > 5

    if UserOauthState.find_by(state: state, user: user).nil?
      raise "Could not create unique state"
    end

    # Generate login url
    client.auth_code.authorize_url(redirect_uri: self.d2l_redirect_uri, 'scope' => 'core:*:* enrollment:orgunit:read grades:*:*', 'state' => state)
  end

  def self.process_callback(code, state)
    client = self.oauth_client

    begin
      # Get the access token
      access_token = client.auth_code.get_token(
        code,
        redirect_uri: self.d2l_redirect_uri
      )
    rescue OAuth2::Error => e
      Rails.logger.error("Error getting oauth access token: #{e.message}")
      raise(StandardError, "Error getting access token")
    end

    # Extract the token needed to be stored
    token = access_token.token

    # Find the state in the user_oauth_states table
    user_oauth_state = UserOauthState.find_by(state: state)

    raise(StandardError, "Invalid state") if user_oauth_state.nil?

    Rails.logger.info("User #{user_oauth_state.user.id} logged in with D2L")
    Rails.logger.info("Token: #{access_token.to_hash}")

    # Create a user oauth token
    UserOauthToken.create(
      user: user_oauth_state.user,
      provider: :d2l,
      token: token,
      expires_at: Time.zone.now + 30.minutes
    )

    user_oauth_state.destroy
  end

end
