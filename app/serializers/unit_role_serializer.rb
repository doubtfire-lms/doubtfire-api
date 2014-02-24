class UnitRoleSerializer < ActiveModel::Serializer
  attributes :id, :role_id, :user_id

  has_one :user
  has_one :unit, serializer: ShallowUnitSerializer
  has_one :role
end
