class UnitSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :start_date, :end_date, :active, :code, :convenors

  has_many :tutorials
  has_many :convenors
end
