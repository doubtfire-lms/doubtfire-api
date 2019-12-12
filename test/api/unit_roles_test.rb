require 'test_helper'

class UnitRolesTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # GET /api/units_roles
  def test_get_unit_roles
    get '/api/unit_roles'
    # UnitRole.joins(:role, :unit).where("user_id = :user_id and roles.name <> 'Student'", user_id: user.id)

    # asserts
  end

  # Get a unit role's details
  def test_get_a_unit_roles_details
    expected_ur = UnitRole.second

    # perform the GET 
    get with_auth_token"/api/unit_roles/#{expected_ur.id}"
    returned_ur = last_response_body

    # Check if the call succeeds
    assert_equal 200, last_response.status
    
    # Check the returned details match as expected
    response_keys = %w(unit_id user_id)
    assert_json_matches_model(returned_ur, expected_ur, response_keys)
  end
  
  def test_post_bad_unit_roles
    num_of_unit_roles = UnitRole.all.count

    to_post = {
      unit_id: 1,
      user_id: 1,
      role: 'asdf'
    }

    post '/api/unit_roles', with_auth_token(to_post)
    assert_equal last_response.status, 403
    assert_equal num_of_unit_roles, UnitRole.all.count
  end

  def test_post_unit_roles_not_unique
    num_of_unit_roles = UnitRole.all.count
    to_post = {
      unit_id: 1,
      user_id: 1,
      role: 'tutor'
    }
    post '/api/unit_roles', with_auth_token(to_post)

    assert_equal last_response.status, 201
    assert_equal num_of_unit_roles, UnitRole.all.count

    assert_equal to_post[:unit_id], last_response_body['unit_id']
    assert_equal to_post[:user_id], last_response_body['user_id']
  end

  # PUT tests
  # Replace a unit role
  def test_put_unit_role
    # Details to replace
    data_to_put = {
      unit_role: FactoryGirl.build(:unit_role),
      auth_token: auth_token
    }

    # Update unit_role with id = 1
    put_json '/api/unit_roles/1', data_to_put
    
    # Check if the PUT get through
    assert_equal 200, last_response.status
    
    # Check if the details replaced match as expected
    response_keys = %w(unit_id user_id)
    first_unit_role = UnitRole.first
    assert_json_matches_model(last_response_body, first_unit_role, response_keys)
  end

  # DELETE tests
  # Delete a unit role
  def test_delete_unit_role
    number_of_ur = UnitRole.all.count

    unit_role = TeachingPeriod.all.first
    id_of_ur = unit_role.id
    
    # perform the delete
    delete_json with_auth_token"/api/unit_roles/#{unit_role.id}"
    
    # Check if the delete get through
    assert_equal 200, last_response.status
    
    # check if the number of unit roles reduces by 1
    assert_equal UnitRole.count, number_of_ur -1

    # Check that you can't find the deleted id
    refute UnitRole.exists?(id_of_ur)
  end

  # Delete a teaching period using unauthorised account
  def test_student_delete_unit_role
    user = FactoryGirl.build(:user, :student)

    number_of_ur = UnitRole.count

    unit_role = TeachingPeriod.second
    id_of_ur = unit_role.id

    # perform the delete
    delete_json with_auth_token("/api/unit_roles/#{id_of_ur}", user)

    # check if the delete does not get through
    assert_equal 403, last_response.status

    # check if the number of unit roles is still the same
    assert_equal UnitRole.count, number_of_ur

    # Check that you still can find the deleted id
    assert UnitRole.exists?(id_of_ur)
  end
end
