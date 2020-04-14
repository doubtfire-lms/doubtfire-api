require "test_helper"

class AuthTokenTest < ActiveSupport::TestCase
  def test_token_is_unique
    # Create a token...
    user = FactoryBot.create(:user)
    token = user.generate_authentication_token!

    # Try to duplicate
    t1 = AuthToken.new(user_id: user.id, authentication_token: token.authentication_token, auth_token_expiry: token.authentication_token)

    refute t1.valid?
  end

  def test_clean_up
    # Create a token...
    user = FactoryBot.create(:user)
    token = user.generate_authentication_token!

    token.auth_token_expiry = Time.zone.now - 1.second
    token.save

    AuthToken.destroy_old_tokens

    assert_raises(ActiveRecord::RecordNotFound) { token.reload }
  end
end
