module Entities
  # entities present the data in a specific format to the user
  class CriterionEntity < Grape::Entity
    expose :id
    expose :help_text
    expose :description
    expose :order
  end
end
