require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    def test_connects_with_auth_token
      user = FactoryBot.create(:user)
      token = user.generate_authentication_token!

      connect params: { username: user.username, auth_token: token.authentication_token }

      assert_equal user, connection.current_user
    end

    def test_rejects_missing_token
      user = FactoryBot.create(:user)

      assert_reject_connection { connect params: { username: user.username } }
    end

    def test_rejects_token_for_another_user
      user = FactoryBot.create(:user)
      other_token = FactoryBot.create(:user).generate_authentication_token!

      assert_reject_connection { connect params: { username: user.username, auth_token: other_token.authentication_token } }
    end

    def test_rejects_and_destroys_expired_token
      user = FactoryBot.create(:user)
      token = user.generate_authentication_token!
      token.update!(auth_token_expiry: 1.minute.ago)

      assert_reject_connection { connect params: { username: user.username, auth_token: token.authentication_token } }
      assert_not AuthToken.exists?(token.id)
    end
  end
end
