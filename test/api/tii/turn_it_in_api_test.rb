require 'test_helper'

class TurnItInApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper

  def app
    Rails.application
  end

  def test_accept_eula_requires_a_valid_token
    user = FactoryBot.create(:user)
    path = "/api/tii_eula/users/#{user.id}/accept"

    clear_auth_header
    header 'username', user.username
    put path
    assert_equal 419, last_response.status
    assert_nil user.reload.tii_eula_date

    add_auth_header_for(user: user, auth_token: 'invalid')
    put path
    assert_equal 419, last_response.status
    assert_nil user.reload.tii_eula_date
  end

  def test_accept_eula_only_for_the_authenticated_user
    user = FactoryBot.create(:user)
    other_user = FactoryBot.create(:user)
    add_auth_header_for(user: user)

    put "/api/tii_eula/users/#{other_user.id}/accept"
    assert_equal 403, last_response.status
    assert_nil other_user.reload.tii_eula_date

    put "/api/tii_eula/users/#{user.id}/accept"
    assert_equal 200, last_response.status
    assert_not_nil user.reload.tii_eula_date
  end
end
