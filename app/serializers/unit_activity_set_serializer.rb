class UnitActivitySetSerializer < ActiveModel::Serializer
  attributes :id, :unit_id, :activity_type_id
  has_many :campus_activity_sets
end
