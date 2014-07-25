require 'user_serializer'

class TutorialSerializer < ActiveModel::Serializer
  attributes :id, :unit_id, :meeting_day, :meeting_time, :meeting_location, :abbreviation

  def meeting_time 
    DateTime.parse("01/01/2014 #{object.meeting_time}")
  end 

  has_one :tutor, serializer: ShallowUserSerializer
end
