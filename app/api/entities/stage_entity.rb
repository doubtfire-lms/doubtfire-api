module Entities
  class StageEntity < Grape::Entity
    expose :id
    expose :title
    expose :order
  end
end
