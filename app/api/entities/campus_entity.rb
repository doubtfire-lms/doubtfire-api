module Entities
  class CampusEntity < Grape::Entity
    expose :id
    expose :name
    expose :mode
    expose :abbreviation
    expose :active
  end
end
