require 'test_helper'

class AuthTest < MiniTest::Test
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
        username: "acain",
        password: "password"
    }
    # Get response back for logging in with username 'acain' password 'password'
    post_json '/api/auth.json', data_to_post
    actual_auth = JSON.parse(last_response.body)
    expected_auth = User.first

    # Check that response contains a user.
    assert actual_auth.has_key?('user'), 'Expect response to have a user'
    assert actual_auth.has_key?('auth_token'), 'Expect response to have a auth token'

    response_user_data = actual_auth['user']

    # Check that the returned user has the required details.
    # These match the model object... so can compare in loops
    user_keys = [ 'id', 'email', 'first_name', 'last_name', 'username', 'nickname', 'receive_task_notifications', 'receive_portfolio_notifications', 'receive_feedback_notifications', 'opt_in_to_research', 'has_run_first_time_setup' ]

    assert_json_matches_model(response_user_data, expected_auth, user_keys)

    user_keys.each { |k| assert response_user_data.has_key?(k), "Response has key #{k}" }
    user_keys.each { |k| assert_equal expected_auth[k], response_user_data[k], "Values for key #{k} match" }

    # Check other values returned
    assert_equal expected_auth.name, response_user_data['name'], 'Names match'
    assert_equal expected_auth.role.name, response_user_data['system_role'], 'Roles match'

    assert_equal expected_auth.auth_token, actual_auth['auth_token']
  end

  # Test auth when password is invalid
  def test_fail_auth
    data_to_post = {
        username: "acain",
        password: "password1"
    }
    # Get response back for logging in with username 'acain' password 'password'
    post_json '/api/auth.json', data_to_post
    actual_auth = JSON.parse(last_response.body)

    refute actual_auth.has_key?('user'), 'User not expected if auth fails'
    refute actual_auth.has_key?('auth_token'), 'Auth token not expected if auth fails'

    assert actual_auth.has_key? 'error'
  end

  # Test auth with tutor role
  def test_auth_roles
    post_tests = [
      {
        expect: Role.admin,
        post: {
            username: "acain",
            password: "password"
        }
      },
      {
        expect: Role.convenor,
        post: {
            username: "jrenzella",
            password: "password"
        }
      },
      {
        expect: Role.tutor,
        post: {
            username: "rwilson",
            password: "password"
        }
      },
      {
        expect: Role.student,
        post: {
            username: "acummaudo",
            password: "password"
        }
      }
    ]

    post_tests.each do |test_data|
      # Get response back for logging in with username 'acain' password 'password'
      post_json '/api/auth.json', test_data[:post]
      actual_auth = JSON.parse(last_response.body)

      assert_equal test_data[:expect].name, actual_auth['user']['system_role'], 'Roles match expected role'
    end
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
    put_json "/api/auth/#{auth_token}.json", data_to_put
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
