class TestAttempt < ApplicationRecord
  include ApplicationHelper
  include LogHelper
  include GradeHelper

  belongs_to :task

  def self.permissions
    student_role_permissions = [
      :create,
      :view_own,
      :delete_own
    ]

    tutor_role_permissions = [
      :create,
      :view_own,
      :delete_own
    ]

    convenor_role_permissions = [
      :create,
      :view_own,
      :delete_own
    ]

    nil_role_permissions = []

    {
      student: student_role_permissions,
      tutor: tutor_role_permissions,
      convenor: convenor_role_permissions,
      nil: nil_role_permissions
    }
  end
end
