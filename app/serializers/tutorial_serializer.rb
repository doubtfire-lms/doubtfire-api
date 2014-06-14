require 'user_serializer'

class TutorialSerializer < ActiveModel::Serializer
  attributes :id, :unit_id, :code, :meeting_day, :meeting_time, :meeting_location

  has_one :tutor, serializer: ShallowUserSerializer
end
