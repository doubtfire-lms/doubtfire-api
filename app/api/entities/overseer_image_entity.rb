module Entities
  class OverseerImageEntity < Grape::Entity
    expose :id
    expose :name
    expose :tag
    expose :pulled_image_status
    expose :last_pulled_date
    expose :pulled_image_text
  end
end
