module Entities
  class LearningOutcomeEntity < Grape::Entity
    expose :id
    expose :ilo_number
    expose :abbreviation
    expose :name
    expose :description
  end
end
