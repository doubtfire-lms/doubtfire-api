class LearningOutcomeTaskLinkSerializer < ActiveModel::Serializer
  attributes :id, 
    :description,
    :rating,
    :learning_outcome_id,
    :task_definition_id,
    :task_id
end
