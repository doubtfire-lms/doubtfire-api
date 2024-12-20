module Entities
  class LearningOutcomeEntity < Grape::Entity
    expose :id
    expose :context_type
    expose :context_id
    expose :abbreviation
    expose :short_description
    expose :full_outcome_description
    expose :linked_outcomes, using: LearningOutcomeEntity do |learning_outcome, options|
      learning_outcome.linked_outcomes
    end
  end
end
