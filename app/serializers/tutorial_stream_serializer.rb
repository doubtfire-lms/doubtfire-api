# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class TutorialStreamSerializer < ActiveModel::Serializer
  attributes :id, :name, :abbreviation, :activity_type

  def activity_type
    object.activity_type.abbreviation
  end
end
