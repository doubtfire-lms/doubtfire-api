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
    @unit.enrol_student(@admin, Campus.first)

    assert_equal Role.student, @unit.role_for(@admin)
    assert AuthorisationHelpers.authorise?(@admin, @unit, :update)
  end

  test 'system administrator role takes precedence over a tutor unit role' do
    @unit.employ_staff(@admin, Role.tutor)

    assert_equal Role.tutor, @unit.role_for(@admin)
    assert AuthorisationHelpers.authorise?(@admin, @unit, :update)
  end
end
