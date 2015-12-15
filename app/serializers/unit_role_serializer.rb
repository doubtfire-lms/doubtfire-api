require 'user_serializer'

class ShallowUnitRoleSerializer < ActiveModel::Serializer
	attributes :id, :role

	def role
		object.role.name
	end
end

class UnitRoleSerializer < ActiveModel::Serializer
  attributes :id, :role, :user_id, :unit_id, :unit_name, :name

  # has_one :user, serializer: ShallowUserSerializer
  # has_one :unit, serializer: ShallowUnitSerializer
  # has_one :role

  #TODO: remove this
  has_many :other_roles, serializer: ShallowUnitRoleSerializer

  def role
  	object.role.name
  end

  def unit_id
    object.unit.id
  end

  def unit_name
    object.unit.name
  end

  def name
    object.user.name
  end
end


class UserUnitRoleSerializer < ActiveModel::Serializer
	attributes :id, :user_id, :name, :role #:user_name?

	def role
		object.role.name
	end

  def name
    object.user.name
  end

  def user_name
    object.user.name
  end
end
