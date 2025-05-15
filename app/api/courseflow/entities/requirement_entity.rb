module Courseflow
  module Entities
    class RequirementEntity < Grape::Entity
      expose :id
      expose :unitId
      expose :courseId
      expose :type
      expose :category
      expose :description
      expose :minimum
      expose :maximum
      expose :requirementSetGroupId
    end
  end
end
