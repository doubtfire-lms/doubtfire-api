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

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    get '/api/unit_roles'
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

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    post '/api/unit_roles', to_post
    assert_equal last_response.status, 403
    assert_equal num_of_unit_roles, UnitRole.all.count
  end

  def test_post_unit_roles_not_unique
    unit = FactoryBot.create :unit, with_students: false, stream_count: 0
    num_of_unit_roles = UnitRole.all.count
    to_post = {
      unit_id: unit.id,
      user_id: unit.main_convenor_user.id,
      role: 'tutor'
    }

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    post '/api/unit_roles', to_post

    assert_equal last_response.status, 201
    assert_equal num_of_unit_roles, UnitRole.all.count

    assert_equal to_post[:user_id], last_response_body['user']['id']
    assert_equal 'Convenor', last_response_body['role']

    unit.destroy
  end

  # DELETE tests
  # Delete a unit role
  def test_delete_unit_role
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0
    user = FactoryBot.create :user, :convenor
    unit_role = unit.employ_staff user, Role.convenor
    id_of_ur = unit_role.id

    number_of_ur = UnitRole.count

    # Add username and auth_token to Header
    add_auth_header_for(user: User.first)

    # perform the delete
    delete_json "/api/unit_roles/#{unit_role.id}"

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

    # Add username and auth_token to Header
    add_auth_header_for(user: student)

    # perform the delete
    delete_json "/api/unit_roles/#{id_of_ur}"

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

    # Add username and auth_token to Header
    add_auth_header_for(user: unit.main_convenor_user)

    # Test delete... of main convenor role
    delete "/api/unit_roles/#{initial_id}"

    assert_equal 400, last_response.status, last_response.inspect

    # They should still be the main convenor
    unit.reload
    assert_equal initial_id, unit.main_convenor_id
    assert UnitRole.find(initial_id).present?

    unit.update(main_convenor_id: convenor_user_role.id)
    unit.reload

    # Now it can work...

    delete "/api/unit_roles/#{initial_id}"
    assert_equal 200, last_response.status, last_response.inspect
    refute UnitRole.where(id: initial_id).present?
  end

  def test_delete_unit_role_with_assigned_tutorials_requires_reassignment
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 1
    tutor_user = FactoryBot.create :user, :tutor
    tutor_role = unit.employ_staff tutor_user, Role.tutor
    tutorial = FactoryBot.create :tutorial, unit: unit, unit_role: tutor_role

    add_auth_header_for(user: unit.main_convenor_user)

    delete "/api/unit_roles/#{tutor_role.id}"

    assert_equal 400, last_response.status
    assert_equal tutor_role.id, tutorial.reload.unit_role_id
    assert UnitRole.exists?(tutor_role.id)
  end

  def test_delete_unit_role_with_assigned_tutorials_reassigns_and_deletes
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 1
    tutor_user = FactoryBot.create :user, :tutor
    replacement_user = FactoryBot.create :user, :tutor
    tutor_role = unit.employ_staff tutor_user, Role.tutor
    replacement_role = unit.employ_staff replacement_user, Role.tutor
    tutorial = FactoryBot.create :tutorial, unit: unit, unit_role: tutor_role

    add_auth_header_for(user: unit.main_convenor_user)

    delete "/api/unit_roles/#{tutor_role.id}", { reassign_to_unit_role_id: replacement_role.id }

    assert_equal 200, last_response.status
    assert_equal replacement_role.id, tutorial.reload.unit_role_id
    refute UnitRole.exists?(tutor_role.id)
  end

  def test_delete_unit_role_with_assigned_tutorials_rejects_invalid_reassignment_target
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 1
    other_unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 1
    tutor_user = FactoryBot.create :user, :tutor
    tutor_role = unit.employ_staff tutor_user, Role.tutor
    invalid_role = other_unit.staff.first
    tutorial = FactoryBot.create :tutorial, unit: unit, unit_role: tutor_role

    add_auth_header_for(user: unit.main_convenor_user)

    delete "/api/unit_roles/#{tutor_role.id}", { reassign_to_unit_role_id: invalid_role.id }

    assert_equal 400, last_response.status
    assert_equal tutor_role.id, tutorial.reload.unit_role_id
    assert UnitRole.exists?(tutor_role.id)
  end

  def test_delete_main_convenor_with_reassignment_rolls_back_tutorial_updates
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 1
    replacement_user = FactoryBot.create :user, :convenor
    replacement_role = unit.employ_staff replacement_user, Role.convenor
    tutorial = FactoryBot.create :tutorial, unit: unit, unit_role: unit.main_convenor
    initial_main_convenor_id = unit.main_convenor_id

    add_auth_header_for(user: unit.main_convenor_user)

    delete "/api/unit_roles/#{initial_main_convenor_id}", { reassign_to_unit_role_id: replacement_role.id }

    assert_equal 400, last_response.status, last_response.inspect
    assert_equal initial_main_convenor_id, tutorial.reload.unit_role_id
    assert UnitRole.exists?(initial_main_convenor_id)
    assert UnitRole.exists?(replacement_role.id)
  end

  def test_admin_not_in_unit_can_update_unit_role
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0

    admin_user = FactoryBot.create :user, :admin
    tutor_user = FactoryBot.create :user, :convenor
    tutor_role = unit.employ_staff tutor_user, Role.tutor

    # The admin is not employed within the unit
    assert_nil unit.unit_role_for(admin_user)

    add_auth_header_for(user: admin_user)

    # Promote the staff member to convenor
    put_json "/api/unit_roles/#{tutor_role.id}", { unit_role: { role_id: Role.convenor.id } }

    assert_equal 200, last_response.status, last_response.inspect
    assert_equal Role.convenor.id, tutor_role.reload.role_id

    # ... and mark them as observer only
    put_json "/api/unit_roles/#{tutor_role.id}", { unit_role: { role_id: Role.convenor.id, observer_only: true } }

    assert_equal 200, last_response.status, last_response.inspect
    assert tutor_role.reload.observer_only

    unit.destroy
  end

  def test_tutor_not_in_unit_cannot_update_unit_role
    unit = FactoryBot.create :unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0

    other_tutor_user = FactoryBot.create :user, :tutor
    tutor_user = FactoryBot.create :user, :convenor
    tutor_role = unit.employ_staff tutor_user, Role.tutor

    add_auth_header_for(user: other_tutor_user)

    put_json "/api/unit_roles/#{tutor_role.id}", { unit_role: { role_id: Role.convenor.id } }

    assert_equal 403, last_response.status, last_response.inspect
    assert_equal Role.tutor.id, tutor_role.reload.role_id

    unit.destroy
  end

  def test_observer_unit_role
    unit = FactoryBot.create(:unit, with_students: true, task_count: 2, tutorials: 1, outcome_count: 0, staff_count: 0, campus_count: 0)

    convenor_user = FactoryBot.create(:user, :convenor)
    convenor_user_role = unit.employ_staff(convenor_user, Role.convenor)

    tutor_user = FactoryBot.create(:user, :tutor)
    tutor_user_role = unit.employ_staff(tutor_user, Role.tutor)

    student_user = FactoryBot.create(:user, :student)

    project = unit.enrol_student(student_user, nil)

    td = unit.task_definitions.first

    task = project.task_for_task_definition(td)
    comment = task.add_text_comment(convenor_user, "Test 1")

    # GET routes
    allowed_routes = [
      "api/unit_roles",
      "api/units/#{unit.id}/tasks/inbox",
      "api/units/#{unit.id}/task_definitions/#{td.id}/tasks",
      "api/projects/#{project.id}/task_def_id/#{td.id}/comments",
      "api/projects/#{project.id}/task_def_id/#{td.id}/submission_details",
      "api/tasks/#{task.id}/similarities",
      "api/projects/#{project.id}/staff_notes"
    ]

    protected_routes = [
      {
        method: 'post',
        path: 'api/projects',
        body: {
          unit_id: unit.id,
          student_num: student_user.username,
          campus_id: Campus.first.id
        }
      },
      {
        method: 'put',
        path: "api/projects/#{project.id}",
        body: {
          enrolled: false
        }
      },
      {
        method: 'post',
        path: "api/projects/#{project.id}/task_def_id/#{td.id}/comments",
        body: {
          comment: "Test"
        }
      },
      {
        method: 'delete',
        path: "api/projects/#{project.id}/task_def_id/#{td.id}/comments/#{comment.id}"
      },

      {
        method: 'put',
        path: "api/unit_roles/#{convenor_user_role.id}",
        body: {
          unit_role: {
            role_id: Role.convenor.id,
            observer_only: false # Attempt to remove observer only access from self
          }
        }
      },
      {
        method: 'post',
        path: "api/units/#{unit.id}/task_definitions/",
        body: {
          task_def: {
            name: "Sample Task",
            description: "This is a test task",
            weighting: 10,
            target_grade: 50,
            start_date: Time.zone.today,
            target_date: Time.zone.today + 7.days,
            abbreviation: "Test1-1",
            restrict_status_updates: true,
            plagiarism_warn_pct: 20,
            is_graded: true,
            max_quality_pts: 5
          }
        }
      },
      {
        method: 'put',
        path: "api/units/#{unit.id}/task_definitions/#{td.id}",
        body: {
          task_def: {
            name: "Renamed task definition"
          }
        }
      },
      {
        method: 'put',
        path: "api/projects/#{project.id}/task_def_id/#{td.id}",
        body: {
          trigger: 'complete'
        }
      }
    ]

    convenor_user_role.update(observer_only: true)
    tutor_user_role.update(observer_only: true)

    protected_routes.each do |route|
      add_auth_header_for(user: convenor_user)
      send(route[:method], route[:path], route[:body])
      assert_equal 403, last_response.status, "#{route[:method]}: #{route[:path]} (#{last_response_body})"
    end

    allowed_routes.each do |route|
      add_auth_header_for(user: convenor_user)
      get route
      assert_not_equal 403, last_response.status, "#{route}: (#{last_response_body})"
    end
  end
end
