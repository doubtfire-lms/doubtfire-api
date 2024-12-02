module Entities
  class LearningOutcomeEntity < Grape::Entity
    expose :id
    expose :context_type
    expose :context_id
    expose :ilo_number
    expose :tag
    expose :name
    expose :description
  end
end
