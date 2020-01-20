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
    get with_auth_token '/api/unit_roles'
    # UnitRole.joins(:role, :unit).where("user_id = :user_id and roles.name <> 'Student'", user_id: user.id)

    assert_equal last_response.status, 200
    assert_equal UnitRole.joins(:role, :unit).where("user_id = :user_id and roles.name <> 'Student'", user_id: User.first.id).count, last_response_body.count
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

  def test_delete_main_convenor
    unit = FactoryGirl.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0

    convenor_user = FactoryGirl.create :user, :convenor
    convenor_user_role = unit.employ_staff convenor_user, Role.convenor

    initial_id = unit.main_convenor_id

    # Test delete... of main convenor role
    delete with_auth_token("/api/unit_roles/#{initial_id}", unit.main_convenor_user)

    assert_equal 400, last_response.status, last_response.inspect

    # They should still be the main convenor
    unit.reload
    assert_equal initial_id, unit.main_convenor_id
    assert UnitRole.find(initial_id).present?

    unit.update(main_convenor_id: convenor_user_role.id)
    unit.reload

    # Now it can work...
    delete with_auth_token("/api/unit_roles/#{initial_id}", unit.main_convenor_user)
    assert_equal 200, last_response.status, last_response.inspect
    refute UnitRole.where(id: initial_id).present?
  end
end
