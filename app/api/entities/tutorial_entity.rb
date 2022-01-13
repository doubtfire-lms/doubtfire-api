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
    expose :num_students #TODO: remove this and request it dynamically when needed
    expose :tutor do |tutorial, options|
      Entities::UserEntity.represent tutorial.tutor, only: [:id, :name]
    end
  end
end
