require 'test_helper'

class AuthTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include ActiveSupport::Testing::TimeHelpers
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
      username: 'aadmin',
      password: 'password',
      remember: true
    }
    # Get response back for logging in with username 'aadmin' password 'password'
    post_json '/api/auth.json', data_to_post
    actual_auth = last_response_body
    expected_auth = User.first

    # Check that response contains a user.
    assert actual_auth.key?('user'), 'Expect response to have a user'
    assert actual_auth.key?('auth_token'), 'Expect response to have a auth token'

    response_user_data = actual_auth['user']

    # Check that the returned user has the required details.
    # These match the model object... so can compare in loops
    user_keys = %w[id email first_name last_name username nickname receive_task_notifications receive_portfolio_notifications receive_feedback_notifications opt_in_to_research has_run_first_time_setup]

    # Check the returned user matches the expected database value
    assert_json_matches_model(expected_auth, response_user_data, user_keys)

    # Check other values returned
    assert_equal expected_auth.role.name, response_user_data['system_role'], 'Roles match'

    token = User.first.token_for_text? actual_auth['auth_token'], :general
    assert token.present?
    assert_equal 'general', token.token_type

    # User has the token - count of matching tokens for that user is 1
    assert_equal 1, expected_auth.auth_tokens.select{|t| t.authentication_token == actual_auth['auth_token']}.count

    # Check we got a refresh token
    assert last_response.cookies['refresh_token'], 'Expect refresh token to be set'
    assert last_response.cookies['username'], 'Expect username to be set'

    refresh_token = User.first.auth_tokens.where(token_type: :refresh_token).last
    assert refresh_token.present?
    assert_equal refresh_token.authentication_token, last_response.cookies['refresh_token'].value, 'Expect refresh token to be set'
    assert_equal User.first.username, last_response.cookies['username'].value, 'Expect username to be set'
  end

  def test_auth_records_sign_in_and_access_time
    user = User.find_by!(username: 'aadmin')
    sign_in_time = Time.zone.parse('2026-07-21 10:00:00 UTC')

    travel_to sign_in_time do
      post_json '/api/auth.json', username: user.username, password: 'password'
    end

    assert_equal 201, last_response.status
    assert_equal sign_in_time, user.reload.last_sign_in_at
    assert_equal sign_in_time, user.last_access_at
  end

  def test_auth_no_remember
    data_to_post = {
      username: 'aadmin',
      password: 'password',
      remember: false
    }
    # Get response back for logging in with username 'aadmin' password 'password'
    post_json '/api/auth.json', data_to_post

    assert_equal 201, last_response.status

    assert_empty last_response.cookies['refresh_token'].value, 'Expect refresh token to be deleted'
    assert_empty last_response.cookies['username'].value, 'Expect username to be deleted'
  end

  # Test auth when username is invalid
  def test_fail_username_auth
    data_to_post = {
      username: 'aadmin123',
      password: 'password'
    }
    # Get response back for logging in with username 'aadmin' password 'password'
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
      username: 'aadmin',
      password: 'password1'
    }

    # Get response back for logging in with username 'aadmin' password 'password1'
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

    # Post empty data
    post_json '/api/auth.json', data_to_post
    actual_auth = last_response_body

    # Check response body doesn't return 'user' and 'auth_token' values
    refute actual_auth.key?('user'), 'User not expected if auth fails'
    refute actual_auth.key?('auth_token'), 'Auth token not expected if auth fails'

    # 400 response code means missing username and password
    assert_equal 400, last_response.status
    assert actual_auth.key?('error'), actual_auth.inspect
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
      # Get response back for logging in with above data
      post_json '/api/auth.json', test_data[:post]
      actual_auth = last_response_body

      assert actual_auth['user'], last_response_body.inspect
      assert_equal test_data[:expect].name, actual_auth['user']['system_role'], 'Roles match expected role'
    end
  end

  # End POST tests
  # --------------------------------------------------------------------------- #

  # # --------------------------------------------------------------------------- #
  # # DELETE tests

  # Test for deleting authentication token
  def test_auth_delete
    # Add authentication token to header
    add_auth_header_for(user: User.first)

    delete "/api/auth", { remember: false }
    # 204 response code means success!
    assert_equal 204, last_response.status

    assert_empty last_response.cookies['username'].value
    assert_empty last_response.cookies['refresh_token'].value
  end

  def test_refresh_token
    user = FactoryBot.create(:user)
    token = user.generate_authentication_token!(token_type: :refresh_token)

    count = user.auth_tokens.count

    set_cookie "username=#{user.username}"
    set_cookie "refresh_token=#{token.authentication_token}"

    post '/api/auth/access-token', { remember: true }

    assert_equal 201, last_response.status
    assert_equal count + 1, user.auth_tokens.count

    new_token = user.auth_tokens.last

    assert_equal :general, new_token.token_type.to_sym
    assert_equal last_response_body['auth_token'], new_token.authentication_token

    # Test using to refresh the auth token
    add_auth_header_for(user: user, auth_token: new_token.authentication_token)

    # Test it returns existing and does not delete old asked not to
    post '/api/auth/access-token', { remember: true, delete_auth_token: false }
    assert_equal count + 1, user.auth_tokens.count
    assert AuthToken.exists?(new_token.id)

    # Test it adds one and deletes the old token
    post '/api/auth/access-token', { remember: true, delete_auth_token: true }
    assert_equal count + 1, user.auth_tokens.count
    assert_not AuthToken.exists?(new_token.id)

    new_new_token = user.auth_tokens.last

    assert_not_equal last_response_body['auth_token'], new_token.authentication_token
    assert_equal last_response_body['auth_token'], new_new_token.authentication_token
  end

  def test_refresh_token_updates_access_but_not_sign_in_time
    user = FactoryBot.create(:user, last_sign_in_at: 1.day.ago, last_access_at: 1.hour.ago)
    original_sign_in_time = user.last_sign_in_at
    token = user.generate_authentication_token!(token_type: :refresh_token)
    access_time = Time.zone.parse('2026-07-21 11:00:00 UTC')

    set_cookie "username=#{user.username}"
    set_cookie "refresh_token=#{token.authentication_token}"

    travel_to(access_time) { post '/api/auth/access-token' }

    assert_equal 201, last_response.status
    assert_equal original_sign_in_time, user.reload.last_sign_in_at
    assert_equal access_time, user.last_access_at
  end

  def test_token_signout_works_with_multiple
    user = FactoryBot.create(:user)
    # Create 2 auth tokens
    t1 = user.generate_authentication_token!
    t2 = user.generate_authentication_token!

    # Set custom headers for request
    # Add authentication token to header
    add_auth_header_for(username: user.username, auth_token: t1.authentication_token)

    # Sign out one
    delete '/api/auth.json', { remember: false }

    t2.reload
    assert_not t2.destroyed?

    assert_raises(ActiveRecord::RecordNotFound) { t1.reload }
  end
  # End DELETE tests
  # --------------------------------------------------------------------------- #

  # # --------------------------------------------------------------------------- #
  # # SCORM auth test

  def test_scorm_auth
    admin = FactoryBot.create(:user, :admin)

    add_auth_header_for(user: admin)

    # All users can access scorm resources
    get "api/auth/scorm"
    assert_equal 200, last_response.status
    assert_equal 1, admin.auth_tokens.where(token_type: :scorm).count

    student = FactoryBot.create(:user, :student)

    student.auth_tokens.where(token_type: :scorm).destroy_all

    add_auth_header_for(user: student)

    # When user is authorised and no prior scorm tokens exist
    get "api/auth/scorm"
    assert_equal 200, last_response.status
    assert last_response_body["scorm_auth_token"]
    assert 2, student.auth_tokens.where(token_type: :scorm).count

    first_token = last_response_body["scorm_auth_token"]

    add_auth_header_for(user: student)

    # When previous valid scorm token exists
    get "api/auth/scorm"
    assert_equal 200, last_response.status
    assert last_response_body["scorm_auth_token"] == first_token

    old_token = student.auth_tokens.find_by(token_type: :scorm)
    old_token.auth_token_expiry = Time.zone.now - 1.day
    old_token.save!

    add_auth_header_for(user: student)

    # When previous expired scorm token exists
    get "api/auth/scorm"
    assert_equal 200, last_response.status
    assert last_response_body["scorm_auth_token"] != first_token
    assert_raises ActiveRecord::RecordNotFound do
      student.auth_tokens.find(old_token.id)
    end
  end

  # End SCORM auth test
  # --------------------------------------------------------------------------- #

  def test_login_token
    unit = FactoryBot.create :unit, with_students: false
    user = unit.main_convenor_user

    token = user.generate_temporary_authentication_token!

    add_auth_header_for(user: user, auth_token: token)

    get 'api/units'

    assert 403, last_response.status

    post 'api/auth'
  ensure
    unit.destroy
  end

  def test_scorm_token
    unit = FactoryBot.create :unit, with_students: false
    user = unit.main_convenor_user

    token = user.generate_scorm_authentication_token!

    add_auth_header_for(user: user, auth_token: token)

    get '/api/units'

    assert 403, last_response.status
  ensure
    unit.destroy
  end
end
