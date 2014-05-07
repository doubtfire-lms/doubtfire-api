class ShallowUnitRoleSerializer < ActiveModel::Serializer
	attributes :id, :role

	def role
		object.role.name
	end
end

class UnitRoleSerializer < ActiveModel::Serializer
  attributes :id, :role_id, :user_id

  has_one :user
  has_one :unit, serializer: ShallowUnitSerializer
  has_one :role

  has_many :other_roles, serializer: ShallowUnitRoleSerializer
end
