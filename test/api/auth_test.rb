require 'test_helper'

class AuthTest < MiniTest::Test
  include Rack::Test::Methods
  include AuthHelper

  def app
    Rails.application
  end

  # --------------------------------------------------------------------------- #
  # --- Endpoint testing for:
  # ------- /api/auth.json
  # ------- POST PUT DELETE

  # --------------------------------------------------------------------------- #
  # POST tests

  # Test POST for new authentication token
  def test_auth_post
    data_to_post = add_auth_token({
        username: "acain",
        password: "password"
    })
    # Get response back for logging in with username 'acain' password 'password'
    post  '/api/auth.json', data_to_post.to_json, "CONTENT_TYPE" => 'application/json'
    actual_auth = JSON.parse(last_response.body)
    expected_auth = User.first

    # Check to see if the username matches what was expected
    assert_equal expected_auth.username, actual_auth['user']['username']
    # Check to see if the first name matches what was expected
    assert_equal expected_auth.first_name, actual_auth['user']['first_name']
    # Check to see if the last name matches what was expected
    assert_equal expected_auth.last_name, actual_auth['user']['last_name']
  end
  # End POST tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # PUT tests

  # Test put for authentication token
  def test_auth_put
    auth_token = get_auth_token
    data_to_put = {
        username: "acain",
        password: "password"
    }
    put "/api/auth/#{auth_token}.json", data_to_put.to_json, "CONTENT_TYPE" => 'application/json'
    actual_auth = JSON.parse(last_response.body)['auth_token']
    expected_auth = User.first.auth_token

    # Check to see if the response auth token matches the auth token that was sent through in put
    assert_equal expected_auth, actual_auth
  end
  # End PUT tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # DELETE tests

  # Test for deleting authentication token
  def test_auth_delete
    auth_token = get_auth_token
    # Get the auth token needed for delete test
    delete "/api/auth/#{auth_token}.json", "CONTENT_TYPE" => 'application/json'
    # 200 response code means success!
    assert_equal 200, last_response.status 
  end
  # End DELETE tests
  # --------------------------------------------------------------------------- #
end
