module Courseflow
  module Entities
    class CourseMapUnitEntity < Grape::Entity
      expose :id
      expose :courseMapId
      expose :unitId
      expose :yearSlot
      expose :teachingPeriodSlot
      expose :unitSlot
    end
  end
end
