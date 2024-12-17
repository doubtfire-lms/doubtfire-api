module D2lIntegration
  module Entities
    class D2lEntity < Grape::Entity
      expose :id
      expose :org_unit_id
      expose :grade_object_id
    end
  end
end
