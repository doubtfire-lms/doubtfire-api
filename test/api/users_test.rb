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
    {
        first_name: 'Akash',
        last_name: 'Agarwal',
        email: 'blah@blah.com',
        username: 'akash',
        nickname: 'akash',
        system_role: 'Admin'
    }
  end

  # ========================================================================
  # GET tests
  # ========================================================================

  def test_get_users
    get with_auth_token '/api/users'
    assert_equal 200, last_response.status
  end

  def test_get_convenors
    get with_auth_token '/api/users/convenors'
    assert_equal 200, last_response.status
  end

  def test_get_tutors
    get with_auth_token '/api/users/tutors'
    assert_equal 200, last_response.status
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

  # ========================================================================
  # POST tests
  # ========================================================================

  def test_post_create_user
    pre_count = User.all.length

    data_to_post = {
        user: create_user,
        auth_token: auth_token
    }

    post_json '/api/users', data_to_post

    assert_equal pre_count + 1, User.all.length
    assert_users_model_response last_response_body, User.last
    assert_equal 201, last_response.status
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
    assert_equal 201, last_response.status

    post_json '/api/users', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal pre_count + 1, User.all.length
    assert_equal 500, last_response.status
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
    assert_equal pre_count + 1, User.all.length

    # Changes username of user in data_to_post automatically
    user[:username] = 'akash2'

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

  def test_post_create_user_empty_required_fields
    pre_count = User.all.length
    user = create_user
    user2 = create_user

    user.collect do |key, value|
      next if key == :nickname # Nickname can be empty
      user2[key] = ''
      data_to_post = {
          user: user2,
          auth_token: auth_token
      }

      post_json '/api/users', data_to_post
      # Successful assertion of same length again means no record was created
      assert_equal pre_count, User.all.length
      assert_equal (if key == :system_role then 403 else 500 end), last_response.status
      user2[key] = value
    end
  end

  def test_post_create_user_custom_role(role='asdasd')
    pre_count = User.all.length
    user = create_user

    user[:system_role] = role

    data_to_post = {
        user: user,
        auth_token: auth_token
    }

    post_json '/api/users', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal pre_count, User.all.length
    assert_equal 403, last_response.status
  end

  def test_post_create_user_role_root
    test_post_create_user_custom_role 'root'
  end

  def test_post_create_user_custom_token(token='asdasd')
    pre_count = User.all.length
    user = create_user

    data_to_post = {
        user: user,
        auth_token: token
    }

    post_json '/api/users', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal pre_count, User.all.length
    assert_equal 419, last_response.status
  end

  def test_post_create_user_empty_token
    test_post_create_user_custom_token ''
  end

  # ========================================================================
  # PUT tests
  # ========================================================================

  def test_put_update_user_valid_email
    user = User.second
    user[:email] = 'different@email.com'

    data_to_put = {
        user: user,
        auth_token: auth_token
    }

    put_json '/api/users/2', data_to_put
    assert_users_model_response User.find_by(email: 'different@email.com').as_json, user.as_json
    assert_equal 200, last_response.status
  end

  def test_put_update_user_existing_email
    user = User.second
    user[:email] = User.third.email

    data_to_put = {
        user: user,
        auth_token: auth_token
    }

    put_json '/api/users/2', data_to_put
    assert_equal 500, last_response.status
  end

  def test_put_update_user_invalid_email
    user = User.second

    invalid_emails = %w(qwertyuiop qwertyuiop@qwe qwertyuiop@.com qwertyuiop@blah..com)

    invalid_emails.each do |email|
      # Assign invalid email
      user[:email] = email

      data_to_put = {
          user: user,
          auth_token: auth_token
      }

      put_json '/api/users/2', data_to_put
      assert_equal 500, last_response.status
    end
  end

  def test_put_update_user_empty_email
    user = User.second
    user[:email] = ''

    data_to_put = {
        user: user,
        auth_token: auth_token
    }

    put_json '/api/users/2', data_to_put
    assert_equal 500, last_response.status
  end

  def test_put_update_user_custom_token(token='asdasd')
    user = User.second
    user[:email] = ''

    data_to_put = {
        user: user,
        auth_token: token
    }

    put_json '/api/users/2', data_to_put
    assert_equal 419, last_response.status
  end

  def test_put_update_user_empty_token
    test_put_update_user_custom_token ''
  end

end
