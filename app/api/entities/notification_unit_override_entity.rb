module Entities
  class NotificationUnitOverrideEntity < Grape::Entity
    expose :unit_id
    expose :muted
    expose :channels
  end
end
