require 'test_helper'

class AuthTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Rails.application
  end

  def test_auth_post
    # Get response back for logging in with username 'acain' password 'password'
    post '/api/auth.json', '{"username":"acain", "password":"password"}', "CONTENT_TYPE" => 'application/json'
    # Check to see if the username matches what was expected
    assert JSON.parse(last_response.body)['user']['username'], 'acain'
    # Check to see if the first name matches what was expected
    assert JSON.parse(last_response.body)['user']['first_name'], 'andrew'
    # Check to see if the last name matches what was expected
    assert JSON.parse(last_response.body)['user']['last_name'], 'cain'
  end

  def test_auth_put
    # Get the auth token needed for put test
    auth_token = JSON.parse((post '/api/auth.json', '{"username":"acain", "password":"password"}', "CONTENT_TYPE" => 'application/json').body)['auth_token']
    put "/api/auth/#{auth_token}.json", '{"username":"acain"}', "CONTENT_TYPE" => 'application/json'
    # Check to see if the response auth token matches the auth token that was sent through in put
    assert JSON.parse(last_response.body)['auth_token'], auth_token
  end

  def test_auth_delete
    # Get the auth token needed for delete test
    auth_token = JSON.parse((post '/api/auth.json', '{"username":"acain", "password":"password"}', "CONTENT_TYPE" => 'application/json').body)['auth_token']
    delete "/api/auth/#{auth_token}.json", "CONTENT_TYPE" => 'application/json'
    # 200 response code means success!
    assert_equal(last_response.status, 200)
  end
end
