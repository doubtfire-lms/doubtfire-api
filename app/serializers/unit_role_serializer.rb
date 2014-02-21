class UnitRoleSerializer < ActiveModel::Serializer
  attributes :id

  has_one :user
  has_one :unit, serializer: ShallowUnitSerializer
  has_one :role
end
