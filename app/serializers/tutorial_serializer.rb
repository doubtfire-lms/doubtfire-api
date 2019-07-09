# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

require 'user_serializer'

class TutorialSerializer < ActiveModel::Serializer
  attributes :id, :meeting_day, :meeting_time, :meeting_location, :abbreviation, :tutor_name, :num_students

  def meeting_time
    object.meeting_time.to_time
    # DateTime.parse("#{object.meeting_time}")
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

  def include_num_students?
    if Thread.current[:user]
      my_role = object.unit.role_for(Thread.current[:user])
      [ Role.convenor, Role.tutor, Role.admin ].include? my_role
    end
  end

  def filter(keys)
    keys.delete :tutor unless include_tutor?
    keys.delete :num_students unless include_num_students?
    keys
  end
end
