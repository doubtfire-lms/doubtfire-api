require 'user_serializer'

class TutorialSerializer < ActiveModel::Serializer
  attributes :id, :meeting_day, :meeting_time, :meeting_location, :abbreviation, :tutor_name

  def meeting_time 
    DateTime.parse("01/01/2014 #{object.meeting_time}")
  end 

  def tutor_name
  	object.tutor.name unless object.tutor.nil?
  end

  has_one :tutor, serializer: ShallowUserSerializer

  def include_tutor?
  	if Thread.current[:user]
      my_role = object.unit.role_for(Thread.current[:user])
      [ Role.convenor, Role.admin ].include? my_role
    end
  end
end
