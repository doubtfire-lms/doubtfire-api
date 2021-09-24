# class TutorialStreamSerializer < DoubtfireSerializer
#   attributes :id, :name, :abbreviation, :activity_type

#   def activity_type
#     object.activity_type.abbreviation
#   end
# end

module Api
  module Entities
    class TutorialStreamEntity < Grape::Entity
      expose :id
      expose :name
      expose :abbreviation
      expose :activity_type do |stream, options|
        stream.activity_type.abbreviation
      end
    end
  end
end
