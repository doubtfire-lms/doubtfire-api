require 'test_helper'

class AuthorisationHelpersTest < ActiveSupport::TestCase
  setup do
    @unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 0,
      tutorials: 0,
      outcome_count: 0,
      staff_count: 0,
      campus_count: 0
    )
    @admin = FactoryBot.create(:user, :admin)
  end

  test 'system administrator role takes precedence over a student unit role' do
    project = @unit.enrol_student(@admin, Campus.first)

    assert_equal Role.student, @unit.role_for(@admin)
    assert AuthorisationHelpers.authorise?(@admin, @unit, :update)
    assert AuthorisationHelpers.authorise?(@admin, project, :make_submission)
  end

  test 'system administrator role takes precedence over an observer-only tutor unit role' do
    @unit.employ_staff(@admin, Role.tutor).update!(observer_only: true)

    assert_equal Role.tutor, @unit.role_for(@admin)
    assert AuthorisationHelpers.authorise?(@admin, @unit, :update)
    assert AuthorisationHelpers.authorise?(@admin, @unit, :provide_feedback)
  end

  test 'observers can read convenor pages without gaining their write permissions' do
    observer = FactoryBot.create(:user, :convenor, observe_all_units: true)
    staff = FactoryBot.create(:user, :tutor)
    staff_role = @unit.employ_staff(staff, Role.tutor)
    request = Rack::Request.new(Rack::MockRequest.env_for('/units/1/communication_sets'))
    authorisation = Object.new.extend(AuthorisationHelpers)
    authorisation.define_singleton_method(:request) { request }

    assert authorisation.authorise?(observer, @unit, :mannage_communications)
    assert authorisation.authorise?(observer, @unit, :add_task_def)
    assert authorisation.authorise?(observer, staff_role, :create_tutor_note)

    request = Rack::Request.new(Rack::MockRequest.env_for('/units/1/communication_sets', method: 'POST'))
    assert_not authorisation.authorise?(observer, @unit, :mannage_communications)
    assert_not authorisation.authorise?(observer, @unit, :add_task_def)
    assert_not authorisation.authorise?(observer, staff_role, :create_tutor_note)

    @unit.employ_staff(observer, Role.convenor).update!(observer_only: true)
    request = Rack::Request.new(Rack::MockRequest.env_for('/units/1/communication_sets'))
    assert authorisation.authorise?(observer, @unit, :mannage_communications)
    assert authorisation.authorise?(observer, staff_role, :create_tutor_note)

    request = Rack::Request.new(Rack::MockRequest.env_for('/units/1/communication_sets', method: 'POST'))
    assert_not authorisation.authorise?(observer, @unit, :mannage_communications)
    assert_not authorisation.authorise?(observer, staff_role, :create_tutor_note)
  end
end
