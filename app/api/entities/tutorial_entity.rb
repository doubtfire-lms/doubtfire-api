# class TutorialSerializer < DoubtfireSerializer
#   attributes :id, :meeting_day, :meeting_time, :meeting_location, :abbreviation, :campus_id, :capacity, :num_students,
#              :tutorial_stream

#   def tutorial_stream
#     object.tutorial_stream.abbreviation unless object.tutorial_stream.nil?
#   end

#   def meeting_time
#     object.meeting_time.to_time
#     # DateTime.parse("#{object.meeting_time}")
#   end

#   has_one :tutor, serializer: ShallowUserSerializer

#   def include_tutor?
#     if Thread.current[:user]
#       my_role = object.unit.role_for(Thread.current[:user])
#       [ Role.convenor, Role.admin ].include? my_role
#     end
#   end

#   def include_num_students?
#     if Thread.current[:user]
#       my_role = object.unit.role_for(Thread.current[:user])
#       [ Role.convenor, Role.tutor, Role.admin ].include? my_role
#     end
#   end

#   def filter(keys)
#     keys.delete :num_students unless include_num_students?
#     keys
#   end
# end


module Api
  module Entities
    class TutorialEntity < Grape::Entity
      expose :id
      expose :meeting_day
      expose :meeting_time # ?? should we use: tutorial.meeting_time.to_time
      expose :meeting_location
      expose :abbreviation
      expose :campus_id
      expose :capacity
      expose :tutorial_stream do |tutorial, options|
        tutorial.tutorial_stream.abbreviation unless tutorial.tutorial_stream.nil?
      end
      expose :num_students
      expose :tutor do |tutorial, options|
        Api::Entities::UserEntity.represent tutorial.tutor, only: [:id, :name, :email]
      end
    end
  end
end
