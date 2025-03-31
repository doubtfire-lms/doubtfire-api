module Courseflow
  module Entities
    class CourseMapEntity < Grape::Entity
      expose :id
      expose :userId
      expose :courseId
    end
  end
end
