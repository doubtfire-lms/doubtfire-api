module Courseflow
  class CourseMapUnit < ApplicationRecord
    # Validation rules for attributes in the course map unit model
    validates :courseMapId, presence: true
    validates :unitId, presence: true
    validates :yearSlot, presence: true
    validates :teachingPeriodSlot, presence: true
    validates :unitSlot, presence: true
  end
end
