# frozen_string_literal: true

# This is an oauth access token to connect to an external service
class UserOauthToken < ApplicationRecord
  belongs_to :user

  encrypts :token

  validates :token, presence: true

  # Ensure a known provider - what the token gives access to
  enum provider: {
    d2l: 0
  }

  # Get the provider as a symbol
  def provider_sym
    provider.to_sym
  end

  # Get access token - used to make http requests
  def access_token
    case provider_sym
    when :d2l
      client = D2lIntegration.oauth_client
    else
      raise "Unknown provider"
    end

    OAuth2::AccessToken.new(client, token)
  end

  def self.destroy_old_tokens
    UserOauthToken.where('expires_at < ?', Time.zone.now).delete_all
  end
end
