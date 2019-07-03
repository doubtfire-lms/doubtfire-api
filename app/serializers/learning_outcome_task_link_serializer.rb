# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class LearningOutcomeTaskLinkSerializer < ActiveModel::Serializer
  attributes :id,
             :description,
             :rating,
             :learning_outcome_id,
             :task_definition_id,
             :task_id
end
