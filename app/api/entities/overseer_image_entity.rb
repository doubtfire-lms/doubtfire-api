module Entities
  class OverseerImageEntity < Grape::Entity
    expose :id
    expose :name
    expose :tag
  end
end
