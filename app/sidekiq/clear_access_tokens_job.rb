# frozen_string_literal: true

# Remove auth tokens and oauth state and tokens that have expired
class ClearAccessTokensJob
  include Sidekiq::Job

  def perform
    UserOauthToken.destroy_old_tokens
    UserOauthState.destroy_old_states

    AuthToken.destroy_old_tokens
  end
end
