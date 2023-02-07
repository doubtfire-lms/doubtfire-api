module Entities
  class TutorialEntity < Grape::Entity
    expose :id
    expose :meeting_day
    expose :meeting_time
    expose :meeting_location
    expose :abbreviation
    expose :campus_id, expose_nil: false
    expose :capacity
    expose :tutorial_stream_abbr, expose_nil: false do |tutorial, options|
      tutorial.tutorial_stream.abbreviation unless tutorial.tutorial_stream.nil?
    end
    expose :num_students # TODO: remove this and request it dynamically when needed
    expose :tutor_id, expose_nil: false do |tutorial, options|
      tutorial.tutor.id unless tutorial.tutor.nil?
    end
  end
end
