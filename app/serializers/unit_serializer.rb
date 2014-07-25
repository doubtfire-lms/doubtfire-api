require 'unit_role_serializer'

class ShallowUnitSerializer < ActiveModel::Serializer
  attributes :code, :id, :name, :start_date, :end_date, :active
end

class UnitSerializer < ActiveModel::Serializer
  attributes :code, :id, :name, :description, :start_date, :end_date, :active, :convenors

  def start_date
    object.start_date.to_date
  end

  def end_date 
    object.end_date.to_date
  end

  has_many :tutorials
  has_many :task_definitions
  has_many :convenors, serializer: UserUnitRoleSerializer
  has_many :staff, serializer: UserUnitRoleSerializer
end
