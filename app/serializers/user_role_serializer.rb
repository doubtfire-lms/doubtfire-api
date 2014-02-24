class UserRoleSerializer < ActiveModel::Serializer
  attributes :id, :role_id, :user_id

  has_one :role
  has_one :user
end
