module Courseflow
  class CourseMap < ApplicationRecord
    # Validation rules for attributes in the course map model
    validates :userId, presence: true
    validates :courseId, presence: true
  end
end
