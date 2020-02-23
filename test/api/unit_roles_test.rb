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

  # Get a unit role's details
  def test_get_a_unit_roles_details
    # create a unit
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0
    user = FactoryBot.create :user, :convenor
    expected_ur = unit.employ_staff user, Role.convenor

    # # newly created unit's main convenor
    # expected_ur = unit.employ_staff, Role.convenor

    # perform the GET
    get (with_auth_token"/api/unit_roles/#{expected_ur.id}", unit.main_convenor_user)
    returned_ur = last_response_body

    # Check if the call succeeds
    assert_equal 200, last_response.status

    # Check the returned details match as expected
    response_keys = %w(unit_id user_id)
    assert_json_matches_model(expected_ur, returned_ur, response_keys)
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

  # DELETE tests
  # Delete a unit role
  def test_delete_unit_role
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0
    user = FactoryBot.create :user, :convenor
    unit_role = unit.employ_staff user, Role.convenor
    id_of_ur = unit_role.id

    number_of_ur = UnitRole.count

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
  def test_student_cannot_delete_unit_role
    student = FactoryBot.build(:user, :student)
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0
    convenor = FactoryBot.create :user, :convenor
    unit_role = unit.employ_staff convenor, Role.convenor
    id_of_ur = unit_role.id

    number_of_ur = UnitRole.count

    # perform the delete
    delete_json with_auth_token("/api/unit_roles/#{id_of_ur}", student)

    # check if the delete does not get through
    assert_equal 403, last_response.status

    # check if the number of unit roles is still the same
    assert_equal UnitRole.count, number_of_ur

    # Check that you still can find the deleted id
    assert UnitRole.exists?(id_of_ur)
  end

  def test_delete_main_convenor
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0

    convenor_user = FactoryBot.create :user, :convenor
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
