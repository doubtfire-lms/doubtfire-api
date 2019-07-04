# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class LearningOutcomeSerializer < ActiveModel::Serializer
  attributes :id, :ilo_number, :abbreviation, :name, :description
end
