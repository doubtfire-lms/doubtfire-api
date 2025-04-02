module Entities
  class LearningOutcomeEntity < Grape::Entity
    expose :id
    expose :context_type
    expose :context_id
    expose :abbreviation
    expose :short_description
    expose :full_outcome_description
    expose :linked_outcome_ids do |learning_outcome, _options|
      learning_outcome.linked_outcomes.pluck(:id)
    end
  end
end
