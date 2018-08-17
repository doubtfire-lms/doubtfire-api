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

  def create_user
    user = {
        first_name: 'Akash',
        last_name: 'Agarwal',
        email: 'blah@blah.com',
        username: 'akash',
        nickname: 'akash',
        system_role: 'Admin'
    }
    user
  end

  # GET tests

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

  def test_get_no_token
    models = %w(users users/tutors users/convenors)

    models.each do |m|
      get "/api/#{m}"
      assert_equal 419, last_response.status
    end
  end

  def test_get_invalid_token
    models = %w(users users/tutors users/convenors)

    models.each { |m|
      get "/api/#{m}?auth_token=1234"
      assert_equal 419, last_response.status
    }
  end

  # POST tests

  def test_post_create_user
    pre_count = User.all.length

    data_to_post = {
        user: create_user,
        auth_token: auth_token
    }

    post_json '/api/users', data_to_post

    assert_equal pre_count + 1, User.all.length
    assert_users_model_response last_response_body, User.last

  end

  def test_post_create_same_user_again
    pre_count = User.all.length

    data_to_post = {
        user: create_user,
        auth_token: auth_token
    }

    post_json '/api/users', data_to_post
    assert_equal pre_count + 1, User.all.length
    assert_users_model_response last_response_body, User.last

    post_json '/api/users', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal pre_count + 1, User.all.length
  end

  def test_post_create_same_user_different_email
    pre_count = User.all.length
    user = create_user

    data_to_post = {
        user: user,
        auth_token: auth_token
    }

    post_json '/api/users', data_to_post
    assert_equal pre_count + 1, User.all.length

    # Changes email of user in data_to_post automatically
    user[:email] = 'different@email.com'

    post_json '/api/users', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal pre_count + 1, User.all.length
    assert_equal 500, last_response.status
  end

  def test_post_create_same_user_different_username
    pre_count = User.all.length
    user = create_user

    data_to_post = {
        user: user,
        auth_token: auth_token
    }

    post_json '/api/users', data_to_post
    # p "Users length: #{User.all.length}"
    assert_equal pre_count + 1, User.all.length

    # Changes username of user in data_to_post automatically
    user[:username] = 'akash2'

    #p "Data to post user: #{data_to_post[:user]}"

    post_json '/api/users', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal pre_count + 1, User.all.length
    assert_equal 500, last_response.status
  end

  def test_post_create_user_invalid_email
    pre_count = User.all.length
    user = create_user

    invalid_emails = %w(qwertyuiop qwertyuiop@qwe qwertyuiop@.com qwertyuiop@blah..com)

    invalid_emails.each do |email|
      # Assign invalid email
      user[:email] = email

      data_to_post = {
          user: user,
          auth_token: auth_token
      }

      post_json '/api/users', data_to_post
      # Successful assertion of same length again means no record was created
      assert_equal pre_count, User.all.length
      assert_equal 500, last_response.status
    end
  end

end
