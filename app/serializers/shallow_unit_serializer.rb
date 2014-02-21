class ShallowUnitSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :start_date, :end_date, :active, :code
end
