class ProjectSerializer < ActiveModel::Serializer
  attributes :unit_id, :unit_role_id, :started, :progress, :status

  has_one :unit, :unit_role
end
