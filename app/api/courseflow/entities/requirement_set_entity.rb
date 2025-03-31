module Courseflow
  module Entities
    class RequirementSetEntity < Grape::Entity
      expose :id
      expose :requirementSetGroupId
      expose :description
      expose :unitId
      expose :requirementId
    end
  end
end
