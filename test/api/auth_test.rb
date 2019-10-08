require 'test_helper'

class AuthTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

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
    data_to_post = {
      username: 'acain',
      password: 'password'
    }
    # Get response back for logging in with username 'acain' password 'password'
    post_json '/api/auth.json', data_to_post
    actual_auth = last_response_body
    expected_auth = User.first

    # Check that response contains a user.
    assert actual_auth.key?('user'), 'Expect response to have a user'
    assert actual_auth.key?('auth_token'), 'Expect response to have a auth token'

    response_user_data = actual_auth['user']

    # Check that the returned user has the required details.
    # These match the model object... so can compare in loops
    user_keys = %w(id email first_name last_name username nickname receive_task_notifications receive_portfolio_notifications receive_feedback_notifications opt_in_to_research has_run_first_time_setup)

    assert_json_matches_model(response_user_data, expected_auth, user_keys)

    user_keys.each { |k| assert response_user_data.key?(k), "Response has key #{k}" }
    user_keys.each { |k| assert_equal expected_auth[k], response_user_data[k], "Values for key #{k} match" }

    # Check other values returned
    assert_equal expected_auth.name, response_user_data['name'], 'Names match'
    assert_equal expected_auth.role.name, response_user_data['system_role'], 'Roles match'

    assert_equal expected_auth.auth_token, actual_auth['auth_token']
  end

  # Test auth when username is invalid
  def test_fail_username_auth
    data_to_post = {
      username: 'acain123',
      password: 'password'
    }
    # Get response back for logging in with username 'acain' password 'password'
    post_json '/api/auth.json', data_to_post
    actual_auth = last_response_body
    
    # Check response body doesn't return 'user' and 'auth_token' values
    refute actual_auth.key?('user'), 'User not expected if auth fails'
    refute actual_auth.key?('auth_token'), 'Auth token not expected if auth fails'
    
    # 401 response code means invalid username / password
    assert_equal 401, last_response.status
    assert actual_auth.key? 'error'
  end

  # Test auth when password is invalid
  def test_fail_password_auth
    data_to_post = {
      username: 'acain',
      password: 'password1'
    }
    
    # Get response back for logging in with username 'acain' password 'password'
    post_json '/api/auth.json', data_to_post
    actual_auth = last_response_body

    # Check response body doesn't return 'user' and 'auth_token' values
    refute actual_auth.key?('user'), 'User not expected if auth fails'
    refute actual_auth.key?('auth_token'), 'Auth token not expected if auth fails'

    assert actual_auth.key? 'error'
  end
  
  # Test auth with empty request body
  def test_fail_empty_request
    data_to_post = ""
  
    # Get response back for logging in with username 'acain' password 'password'
    post_json '/api/auth.json', data_to_post
    actual_auth = last_response_body
    
    # Check response body doesn't return 'user' and 'auth_token' values
    refute actual_auth.key?('user'), 'User not expected if auth fails'
    refute actual_auth.key?('auth_token'), 'Auth token not expected if auth fails'
    
    # 400 response code means missing username and password
    assert_equal 400, last_response.status
    assert actual_auth.key? 'error'
  end

  # Test auth with tutor role
  def test_auth_roles
    post_tests = [
      {
        expect: Role.admin,
        post: {
          username: 'aadmin',
          password: 'password'
        }
      },
      {
        expect: Role.convenor,
        post: {
          username: 'aconvenor',
          password: 'password'
        }
      },
      {
        expect: Role.tutor,
        post: {
          username: 'atutor',
          password: 'password'
        }
      },
      {
        expect: Role.student,
        post: {
          username: 'astudent',
          password: 'password'
        }
      }
    ]

    post_tests.each do |test_data|
      # Get response back for logging in with username 'acain' password 'password'
      post_json '/api/auth.json', test_data[:post]
      actual_auth = last_response_body

      assert_equal test_data[:expect].name, actual_auth['user']['system_role'], 'Roles match expected role'
    end
  end

  # End POST tests
  # --------------------------------------------------------------------------- #

  # GET tests
  #------------------------------------------------------------------------------
  # Test get authentication method configuration
  def test_auth_method_config

    get '/api/auth/method'
    actual_auth = last_response_body

    assert_equal 200, last_response.status

  end

  #Test authentication signout url
  def test_auth_signout_url

    get '/api/auth/signout_url'

    assert_equal 200, last_response.status

  end
  
  # --------------------------------------------------------------------------- #
  # PUT tests

  # Test put for authentication token
  def test_auth_put
    data_to_put = {
      username: 'acain',
      password: 'password'
    }
    put_json "/api/auth/#{auth_token}", data_to_put
    actual_auth = last_response_body['auth_token']
    expected_auth = User.first.auth_token
    # Check to see if the response auth token matches the auth token that was sent through in put
    assert_equal expected_auth, actual_auth
  end
  
  # Test invalid authentication token
  def test_fail_auth_put
    data_to_put = {
      username: 'acain',
    }
    
    put_json "/api/auth/1234", data_to_put
    actual_auth = last_response_body
    expected_auth = User.first.auth_token
    
    # 404 response code means invalid token
    assert_equal 404, last_response.status
    
    # Check to see if the response is invalid
    assert actual_auth.key? 'error'
  end
    
  # Test invalid username for valid authentication token
  def test_fail_username_put
    data_to_put = {
      username: 'acain123'
    }
    
    put_json "/api/auth/#{auth_token}", data_to_put
    actual_auth = last_response_body
    expected_auth = User.first.auth_token
    
    # 404 response code means invalid token
    assert_equal 404, last_response.status
    
    # Check to see if the response is invalid
    assert actual_auth.key? 'error'
  end


  # Test valid username for empty authentication token
  def test_fail_empty_authKey_put
    data_to_put = {
      username: 'acain'
    }
    
    put_json "/api/auth/", data_to_put
    actual_auth = last_response_body
    expected_auth = User.first.auth_token
    
    # 405 response code means empty token
    assert_equal 405, last_response.status
    
    # Check to see if the response is invalid
    assert actual_auth.key? 'error'
  end
  
  # Test empty request
  def test_fail_empty_body_put
    data_to_put = {
    }

    put_json "/api/auth/#{auth_token}", data_to_put
    actual_auth = last_response_body
    expected_auth = User.first.auth_token
    
    # 400 response code means empty body
    assert_equal 400, last_response.status
    
    # Check to see if the response is invalid
    assert actual_auth.key? 'error'
  end
  # End PUT tests
  # --------------------------------------------------------------------------- #

  # --------------------------------------------------------------------------- #
  # DELETE tests

  # Test for deleting authentication token
  def test_auth_delete
    # Get the auth token needed for delete test
    delete "/api/auth/#{auth_token}.json", 'CONTENT_TYPE' => 'application/json'
    # 200 response code means success!
    assert_equal 200, last_response.status
  end
  # End DELETE tests
  # --------------------------------------------------------------------------- #
end
