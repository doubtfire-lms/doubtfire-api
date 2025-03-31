module Courseflow
  module Entities
    class CourseEntity < Grape::Entity
      expose :id
      expose :name
      expose :code
      expose :year
      expose :version
      expose :url
    end
  end
end
