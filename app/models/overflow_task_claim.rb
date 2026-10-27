class OverflowTaskClaim < ApplicationRecord
  belongs_to :task
  belongs_to :claimed_by_unit_role, class_name: 'UnitRole'

end
