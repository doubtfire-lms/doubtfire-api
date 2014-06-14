
class ShallowUnitSerializer < ActiveModel::Serializer
  attributes :id, :name, :start_date, :end_date, :active
end

class UnitSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :start_date, :end_date, :active

  has_many :tutorials
  has_many :task_definitions
end
