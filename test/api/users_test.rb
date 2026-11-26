require 'test_helper'

class UnitsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def assert_users_model_response(response_data, user_model, keys = nil)
    if keys.nil?
      keys = %w[id student_id email first_name last_name username nickname receive_task_notifications
                receive_portfolio_notifications receive_feedback_notifications opt_in_to_research has_run_first_time_setup]
    end

    assert_json_matches_model(user_model, response_data, keys)
  end

  def create_user
    {
      first_name: 'Akash',
      last_name: 'Agarwal',
      email: 'blah@blah.com',
      username: 'akash',
      nickname: 'akash',
      system_role: 'Admin',
      student_id: 'zz123456zz'
    }
  end

  # ========================================================================
  # GET tests
  # ========================================================================

  # Get users' details
  def test_get_users
    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    get '/api/users'
    expected_data = User.all

    # Check if the request get through
    assert_equal 200, last_response.status

    # Check if the GET returned the exact number of users
    assert_equal expected_data.count, last_response_body.count

    # What are the keys we expect in the data that match the model - so we can check these
    response_keys = %w[first_name last_name email student_id nickname receive_task_notifications receive_portfolio_notifications receive_feedback_notifications opt_in_to_research has_run_first_time_setup]

    # Loop through all of the responses
    last_response_body.each do |data|
      # Find the matching user, by id from response
      user = User.find(data['id'])
      # Match json with object
      assert_json_matches_model(user, data, response_keys)
    end
  end

  # Get a user's details
  def test_get_a_users_details
    expected_user = User.second

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    # perform the GET
    get "/api/users/#{expected_user.id}"
    returned_user = last_response_body

    # Check if the call succeeds
    assert_equal 200, last_response.status

    # Check the returned details match as expected
    response_keys = %w[first_name last_name email student_id nickname receive_task_notifications receive_portfolio_notifications receive_feedback_notifications opt_in_to_research has_run_first_time_setup]
    assert_json_matches_model(expected_user, returned_user, response_keys)
  end

  def test_get_user_unit_memberships
    admin = FactoryBot.create(:user, :admin)
    staff = FactoryBot.create(:user, :tutor)
    student = FactoryBot.create(:user, :student)
    teaching_period = FactoryBot.create(:teaching_period)
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, staff_count: 0, teaching_period: teaching_period)
    FactoryBot.create(:unit_role, unit: unit, user: staff, role: Role.tutor)
    project = FactoryBot.create(:project, unit: unit, user: student)

    add_auth_header_for(user: admin)

    get "/api/users/#{staff.id}/unit_memberships"
    assert_equal 200, last_response.status
    assert_equal [{
      'kind' => 'staff',
      'unit_id' => unit.id,
      'unit_code' => unit.code,
      'unit_name' => unit.name,
      'teaching_period_name' => "#{teaching_period.period} #{teaching_period.year}",
      'active' => true,
      'role' => 'Tutor'
    }], last_response_body

    get "/api/users/#{student.id}/unit_memberships"
    assert_equal 200, last_response.status
    assert_equal project.id, last_response_body.first['project_id']
    assert_equal unit.name, last_response_body.first['unit_name']
    assert_equal 'Student', last_response_body.first['role']
    assert_equal true, last_response_body.first['active']

    unit.update!(active: false)
    get "/api/users/#{staff.id}/unit_memberships"
    assert_equal false, last_response_body.first['active']

    project.update!(enrolled: false)
    get "/api/users/#{student.id}/unit_memberships"
    assert_equal [], last_response_body
  end

  def test_students_cannot_get_other_users_unit_memberships
    student = FactoryBot.create(:user, :student)
    other_user = FactoryBot.create(:user, :student)

    add_auth_header_for(user: student)
    get "/api/users/#{other_user.id}/unit_memberships"

    assert_equal 403, last_response.status
  end

  def test_get_convenors
    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    get '/api/users/convenors'
    assert_equal 200, last_response.status
  end

  def test_get_tutors
    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    get '/api/users/tutors'
    assert_equal 200, last_response.status
  end

  def test_only_admin_can_grant_and_revoke_observe_all_units
    admin = FactoryBot.create(:user, :admin)
    observer = FactoryBot.create(:user, :tutor)
    other_tutor = FactoryBot.create(:user, :tutor)

    add_auth_header_for(user: other_tutor)
    put_json "/api/users/#{observer.id}", { user: { observe_all_units: true } }
    assert_equal 403, last_response.status
    assert_not observer.reload.observe_all_units?

    add_auth_header_for(user: admin)
    put_json "/api/users/#{observer.id}", { user: { observe_all_units: true } }
    assert_equal 200, last_response.status
    assert_equal true, last_response_body['observe_all_units']
    assert observer.reload.observe_all_units?

    add_auth_header_for(user: observer)
    put_json "/api/users/#{observer.id}", { user: { nickname: 'Observer', observe_all_units: true } }
    assert_equal 200, last_response.status

    put_json "/api/users/#{observer.id}", { user: { observe_all_units: false } }
    assert_equal 403, last_response.status
    assert observer.reload.observe_all_units?

    add_auth_header_for(user: admin)
    put_json "/api/users/#{observer.id}", { user: { observe_all_units: false } }
    assert_equal 200, last_response.status
    assert_equal false, last_response_body['observe_all_units']
    assert_not observer.reload.observe_all_units?
  end

  def test_observe_all_units_requires_tutor_or_convenor_system_role
    admin = FactoryBot.create(:user, :admin)
    student = FactoryBot.create(:user, :student)
    convenor = FactoryBot.create(:user, :convenor)

    add_auth_header_for(user: admin)
    put_json "/api/users/#{student.id}", { user: { observe_all_units: true } }
    assert_equal 422, last_response.status
    assert_not student.reload.observe_all_units?

    put_json "/api/users/#{convenor.id}", { user: { observe_all_units: true } }
    assert_equal 200, last_response.status
    assert convenor.reload.observe_all_units?

    put_json "/api/users/#{convenor.id}", { user: { system_role: 'Student' } }
    assert_equal 422, last_response.status
    assert_equal Role.convenor, convenor.reload.role
  end

  def test_get_no_token
    models = %w[users users/tutors users/convenors]

    models.each do |m|
      get "/api/#{m}"
      assert_equal 419, last_response.status
    end
  end

  def test_get_invalid_token
    models = %w[users users/tutors users/convenors]

    models.each do |m|
      get "/api/#{m}?auth_token=1234"
      assert_equal 419, last_response.status
    end
  end

  # ========================================================================
  # POST tests
  # ========================================================================

  def test_post_create_user
    pre_count = User.all.length

    data_to_post = {
      user: create_user
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    post_json '/api/users', data_to_post

    assert_equal pre_count + 1, User.all.length
    assert_users_model_response last_response_body, User.last
    assert_equal 201, last_response.status
  end

  def test_post_create_same_user_again
    pre_count = User.all.length

    data_to_post = {
      user: create_user
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    post_json '/api/users', data_to_post
    assert_equal pre_count + 1, User.all.length
    assert_users_model_response last_response_body, User.last
    assert_equal 201, last_response.status

    post_json '/api/users', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal pre_count + 1, User.all.length
    assert_equal 400, last_response.status
  end

  def test_post_create_same_user_different_email
    pre_count = User.all.length
    user = create_user

    data_to_post = {
      user: user
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    post_json '/api/users', data_to_post
    assert_equal pre_count + 1, User.all.length

    # Changes email of user in data_to_post automatically
    user[:email] = 'different@email.com'

    post_json '/api/users', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal pre_count + 1, User.all.length
    assert_equal 400, last_response.status
  end

  def test_post_create_same_user_different_username
    pre_count = User.all.length
    user = create_user

    data_to_post = {
      user: user
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    post_json '/api/users', data_to_post
    assert_equal pre_count + 1, User.all.length

    # Changes username of user in data_to_post automatically
    user[:username] = 'akash2'

    post_json '/api/users', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal pre_count + 1, User.all.length
    assert_equal 400, last_response.status
  end

  def test_post_create_user_invalid_email
    pre_count = User.all.length
    user = create_user

    invalid_emails = %w[qwertyuiop qwertyuiop@qwe qwertyuiop@.com qwertyuiop@blah..com]

    invalid_emails.each do |email|
      # Assign invalid email
      user[:email] = email

      data_to_post = {
        user: user
      }

      # Add username and auth_token to Header
      add_auth_header_for(user: User.first)

      post_json '/api/users', data_to_post
      # Successful assertion of same length again means no record was created
      assert_equal pre_count, User.all.length
      assert_equal 400, last_response.status
    end
  end

  def test_post_create_user_empty_required_fields
    pre_count = User.all.length
    user = create_user
    user2 = create_user

    user.collect do |key, value|
      next if [:nickname, :student_id].include? key # can be empty
      user2[key] = ''
      data_to_post = {
        user: user2
      }

      # Add username and auth_token to Header
      add_auth_header_for(user: User.first)

      post_json '/api/users', data_to_post
      assert_equal (key == :system_role ? 403 : 400), last_response.status, last_response_body
      # Successful assertion of same length again means no record was created
      assert_equal pre_count, User.all.length, last_response_body
      user2[key] = value
    end
  end

  def test_post_create_user_custom_role(role = 'asdasd')
    pre_count = User.all.length
    user = create_user

    user[:system_role] = role

    data_to_post = {
      user: user
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    post_json '/api/users', data_to_post
    # Successful assertion of same length again means no record was created
    assert_equal pre_count, User.all.length
    assert_equal 403, last_response.status
  end

  def test_post_create_user_role_root
    test_post_create_user_custom_role 'root'
  end

  def test_post_create_user_custom_token(token = 'asdasd')
    pre_count = User.all.length
    user = create_user

    data_to_post = {
      user: user
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first, auth_token: token)

    # Override header to empty auth_token
    if token == ''
      header 'auth_token', ''
    end

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
      user: user
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    put_json '/api/users/2', data_to_put
    assert_equal 200, last_response.status
    assert_users_model_response last_response_body, user.reload
  end

  def test_put_update_user_existing_email
    user = User.second
    user[:email] = User.third.email

    data_to_put = {
      user: user
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    put_json '/api/users/2', data_to_put
    assert_equal 400, last_response.status
  end

  def test_put_update_own_timezone
    user = FactoryBot.create(:user, :student)
    add_auth_header_for(user: user)

    put_json "/api/users/#{user.id}", { user: { timezone: 'Asia/Shanghai', auto_timezone: false } }

    assert_equal 200, last_response.status
    assert_equal 'Asia/Shanghai', last_response_body['timezone']
    assert_not user.reload.auto_timezone
  end

  def test_put_update_user_invalid_email
    user = User.second

    invalid_emails = %w[qwertyuiop qwertyuiop@qwe qwertyuiop@.com qwertyuiop@blah..com]

    invalid_emails.each do |email|
      # Assign invalid email
      user[:email] = email

      data_to_put = {
        user: user
      }

      # Add username and auth_token to Header
      add_auth_header_for(user: User.first)

      put_json '/api/users/2', data_to_put
      assert_equal 400, last_response.status
    end
  end

  def test_put_update_user_empty_email
    user = User.second
    user[:email] = ''

    data_to_put = {
      user: user
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    put_json '/api/users/2', data_to_put
    assert_equal 400, last_response.status
  end

  def test_put_update_user_custom_token(token = 'asdasd')
    user = User.second
    user[:email] = ''

    data_to_put = {
      user: user
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first, auth_token: token)

    if token == ''
      header 'auth_token', token
    end

    put_json '/api/users/2', data_to_put
    assert_equal 419, last_response.status
  end

  def test_put_update_user_empty_token
    test_put_update_user_custom_token ''
  end

end
