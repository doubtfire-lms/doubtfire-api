require 'test_helper'

class UnitRolesTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  # Get unit_roles
  def test_get_unit_roles
    get with_auth_token'/api/unit_roles'
	  assert_equal 200, last_response.status
    # UnitRole.joins(:role, :unit).where("user_id = :user_id and roles.name <> 'Student'", user_id: user.id)

    # asserts
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

  # Delete unit role
  def test_unit_roles_delete
    number_of_unit_roles = UnitRole.all.count

    test_unit_role = UnitRole.all.first
    id_of_unit_role_to_delete = test_unit_role.id

    # perform the delete
    delete_json with_auth_token "/api/unit_roles/#{id_of_unit_role_to_delete}"

    # Check there is one less unit_roles
    assert_equal number_of_unit_roles - 1, UnitRole.all.count

    # Check that you can't find the deleted id
    refute UnitRole.exists?(id_of_unit_role_to_delete)
    assert_equal last_response.status, 200
  end
  
end
