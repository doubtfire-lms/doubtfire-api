require "test_helper"

class ProjectModelTest < ActiveSupport::TestCase
  include TestHelpers::TestFileHelper

  # Test that there are 5 roles
  def test_five_roles
    assert_equal 5, Role.count
  end

  # Test the student role
  def test_student_role
    role = Role.student
    assert_equal 'Student', role.name
  end

  # Test the tutor role
  def test_tutor_role
    role = Role.tutor
    assert_equal 'Tutor', role.name
  end

  # Test the convenor role
  def test_convenor_role
    role = Role.convenor
    assert_equal 'Convenor', role.name
  end

  # Test the admin role
  def test_admin_role
    role = Role.admin
    assert_equal 'Admin', role.name
  end

  # Test the auditor role
  def test_auditor_role
    role = Role.auditor
    assert_equal 'Auditor', role.name
  end

  # Test the to_sym method
  def test_to_sym
    role = Role.student
    assert_equal :student, role.to_sym

    role = Role.tutor
    assert_equal :tutor, role.to_sym

    role = Role.convenor
    assert_equal :convenor, role.to_sym

    role = Role.admin
    assert_equal :admin, role.to_sym

    role = Role.auditor
    assert_equal :auditor, role.to_sym
  end

  # Test with_name
  def test_with_name
    role = Role.with_name('Student')
    assert_equal 'Student', role.name

    role = Role.with_name('Tutor')
    assert_equal 'Tutor', role.name

    role = Role.with_name('Convenor')
    assert_equal 'Convenor', role.name

    role = Role.with_name('Admin')
    assert_equal 'Admin', role.name

    role = Role.with_name('Auditor')
    assert_equal 'Auditor', role.name

    role = Role.with_name('asdf')
    assert_nil role

    role = Role.with_name('student')
    assert_equal 'Student', role.name

    role = Role.with_name('tutor')
    assert_equal 'Tutor', role.name

    role = Role.with_name('convenor')
    assert_equal 'Convenor', role.name

    role = Role.with_name('admin')
    assert_equal 'Admin', role.name

    role = Role.with_name('auditor')
    assert_equal 'Auditor', role.name
  end
end
