require 'test_helper'

class AuthTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Rails.application
  end

  def setup
    @auth_token = JSON.parse((post '/api/auth.json', '{"username":"acain", "password":"password"}', "CONTENT_TYPE" => 'application/json').body)['auth_token']
  end

  # --------------------------------------------------------------------------- #
  # --- Endpoint testing for:
  # ------- /api/auth.json
  # ------- POST PUT DELETE

  # --------------------------------------------------------------------------- #
  # POST tests

  # Test POST for new authentication token
  def test_auth_post
    # Get response back for logging in with username 'acain' password 'password'
    post  '/api/auth.json',
          '{'                       +
            '"username":"acain",'   +
            '"password":"password"' +
          '}',
          "CONTENT_TYPE" => 'application/json'

    # Check to see if the username matches what was expected
    assert_equal 'acain', JSON.parse(last_response.body)['user']['username']
    # Check to see if the first name matches what was expected
    assert_equal 'Andrew', JSON.parse(last_response.body)['user']['first_name']
    # Check to see if first name is written in Pascal Case
    refute_equal 'andrew', JSON.parse(last_response.body)['user']['first_name']
    # Check to see if the last name matches what was expected
    assert_equal 'Cain', JSON.parse(last_response.body)['user']['last_name']
    # Check to see if last name is written in Pascal Case
    refute_equal 'cain', JSON.parse(last_response.body)['user']['last_name']
  end
  # End POST tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # PUT tests

  # Test put for authentication token
  def test_auth_put
    put "/api/auth/#{@auth_token}.json",
        '{'                     +
          '"username":"acain"'  +
        '}',
        "CONTENT_TYPE" => 'application/json'

    # Check to see if the response auth token matches the auth token that was sent through in put
    assert_equal @auth_token, JSON.parse(last_response.body)['auth_token']
  end
  # End PUT tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # DELETE tests

  # Test for deleting authentication token
  def test_auth_delete
    # Get the auth token needed for delete test
    delete "/api/auth/#{@auth_token}.json", "CONTENT_TYPE" => 'application/json'
    # 200 response code means success!
    assert_equal last_response.status, 200
  end
  # End DELETE tests
  # --------------------------------------------------------------------------- #
end
