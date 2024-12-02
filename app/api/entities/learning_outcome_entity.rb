module Entities
  class LearningOutcomeEntity < Grape::Entity
    expose :id
    expose :context_type
    expose :context_id
    expose :abbreviation
    expose :short_description
    expose :full_outcome_description
  end
end
