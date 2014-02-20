class TaskDefinitionSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :weighting, :required, :target_date, :abbreviation
end
