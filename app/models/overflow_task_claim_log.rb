class OverflowTaskClaimLog < ApplicationRecord
  belongs_to :unit
  belongs_to :task, optional: true
  belongs_to :claimed_by_unit_role, class_name: 'UnitRole', optional: true
  belongs_to :claimed_by_user, class_name: 'User', optional: true
  belongs_to :original_tutor_user, class_name: 'User', optional: true
  belongs_to :student_user, class_name: 'User', optional: true
end
