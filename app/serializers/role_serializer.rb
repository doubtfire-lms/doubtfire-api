# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class RoleSerializer < ActiveModel::Serializer
  attributes :name, :description
end
