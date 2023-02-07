module Entities
  class TutorialStreamEntity < Grape::Entity
    expose :id
    expose :name
    expose :abbreviation
    expose :activity_type do |stream, options|
      stream.activity_type.abbreviation # TODO: cache all activities in the client and just send the code
    end
  end
end
