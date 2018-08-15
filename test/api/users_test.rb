require 'test_helper'

class UnitsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def assert_users_model_response(actual_user, expected_user)
    keys = %w(id student_id email first_name last_name username nickname receive_task_notifications
           receive_portfolio_notifications receive_feedback_notifications opt_in_to_research has_run_first_time_setup)

    assert_json_matches_model(actual_user, expected_user, keys)
  end

  def test_get_users
    get with_auth_token '/api/users'
    actual_user = last_response_body[0]
    expected_user = User.second

    assert_users_model_response actual_user, expected_user

    # assert_equal expected_user['id'], actual_user['id']
    # assert_equal expected_user.email, actual_user['email']
    # assert_equal expected_user.name, actual_user['name']
    # assert_equal expected_user.first_name, actual_user['first_name']
    # assert_equal expected_user.last_name, actual_user['last_name']
    # assert_equal expected_user.username, actual_user['username']
    # assert_equal expected_user.nickname, actual_user['nickname']
  end

  def test_get_convenors
    get with_auth_token '/api/users/convenors'
    actual_user = last_response_body[0]
    expected_user = User.find 6

    assert_users_model_response actual_user, expected_user
  end

  def test_get_tutors
    get with_auth_token '/api/users/tutors'
    actual_user = last_response_body[0]
    expected_user = User.find 21

    assert_users_model_response actual_user, expected_user
  end

  

  def test_post_users
    pre_count = User.all.length

    user = {
        first_name: 'Akash',
        last_name: 'Agarwal',
        email: 'blah@blah.com',
        username: 'akash',
        nickname: 'akash',
        system_role: 'Admin'
    }

    data_to_post = {
        user: user,
        auth_token: auth_token
    }

    post_json '/api/users', data_to_post

    assert_equal User.all.length, pre_count + 1
    assert_users_model_response last_response_body, User.last

  end

end
