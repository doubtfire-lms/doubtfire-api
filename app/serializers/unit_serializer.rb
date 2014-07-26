require 'unit_role_serializer'

class ShallowUnitSerializer < ActiveModel::Serializer
  attributes :code, :id, :name, :start_date, :end_date, :active
end

class UnitSerializer < ActiveModel::Serializer
  attributes :code, :id, :name, :my_role, :description, :start_date, :end_date, :active, :convenors


  def start_date
    object.start_date.to_date
  end

  def end_date 
    object.end_date.to_date
  end

  def my_role_obj
    if Thread.current[:user]
      object.role_for(Thread.current[:user])
    end
  end

  def my_role
    role = my_role_obj
    role.name unless role.nil?
  end

  has_many :tutorials
  has_many :task_definitions
  has_many :convenors, serializer: UserUnitRoleSerializer
  has_many :staff, serializer: UserUnitRoleSerializer

  def include_convenors?
    [ Role.convenor, Role.admin ].include? my_role_obj
  end

  def include_staff?
    [ Role.convenor, Role.admin ].include? my_role_obj
  end
end
