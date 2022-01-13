module Entities
  class ActivityTypeEntity < Grape::Entity
    expose :id
    expose :name
    expose :abbreviation
  end
end
