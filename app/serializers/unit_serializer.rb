class UnitSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :start_date, :end_date, :active, :code

  has_many :tutorials
end
