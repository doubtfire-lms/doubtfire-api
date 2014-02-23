class UserRoleSerializer < ActiveModel::Serializer
  attributes :id

  has_one :role
  has_one :user
end
