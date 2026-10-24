module Courseflow
  class CourseMap < ApplicationRecord
    # Validation rules for attributes in the course map model
    validates :userId, presence: true, unless: :template?
    validates :courseId, presence: true

    def template?
      userId.nil?
    end
  end
end
