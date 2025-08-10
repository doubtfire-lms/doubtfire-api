require 'test_helper'

class AuthorisationHelpersTest < ActiveSupport::TestCase
  test "observer user cannot perform non-GET actions" do
    role = Role.create!(name: 'Tutor')
    user = User.new(
      email: 'observer@example.com',
      encrypted_password: 'password',
      first_name: 'Observer',
      last_name: 'User',
      username: 'observer_user',
      role: role
    )
    user.save(validate: false)

    unit = Unit.create!(
      name: 'Test Unit',
      code: 'TST101',
      description: 'Test unit description',
      start_date: Date.today,
      end_date: Date.today + 90.days
    )

    unit_role = UnitRole.new(user: user, unit: unit, role: role, observer: true)
    unit_role.save(validate: false)

    unit.define_singleton_method(:role_for) { |_user| :tutor }

    result = AuthorisationHelpers.authorise?(user, unit_role, :post)
    assert_equal false, result
  end

  test "observer user can perform GET actions" do
    role = Role.create!(name: 'Tutor')
    user = User.new(
      email: 'observer@example.com',
      encrypted_password: 'password',
      first_name: 'Observer',
      last_name: 'User',
      username: 'observer_user',
      role: role
    )
    user.save(validate: false)

    unit = Unit.create!(
      name: 'Test Unit',
      code: 'TST101',
      description: 'Test unit description',
      start_date: Date.today,
      end_date: Date.today + 90.days
    )

    unit_role = UnitRole.new(user: user, unit: unit, role: role, observer: true)
    unit_role.save(validate: false)

    unit.define_singleton_method(:role_for) { |_user| :tutor }

    result = AuthorisationHelpers.authorise?(user, unit_role, :get)
    assert_equal true, result
  end
end
