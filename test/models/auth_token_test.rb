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
end
