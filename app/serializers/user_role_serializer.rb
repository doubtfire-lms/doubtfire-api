# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class UserRoleSerializer < ActiveModel::Serializer
  attributes :id, :role_id, :user_id

  has_one :role
  has_one :user
end
