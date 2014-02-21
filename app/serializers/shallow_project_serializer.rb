class ShallowProjectSerializer < ActiveModel::Serializer
  attributes :unit_id, :unit_role_id, :started, :progress, :status  
end
