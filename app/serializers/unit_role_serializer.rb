class UnitRoleSerializer < ActiveModel::Serializer
  has_one :user
  has_one :unit, serializer: ShallowUnitSerializer
  has_one :role
end
