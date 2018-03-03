class GroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :tutorial_id, :group_set_id, :number
end
