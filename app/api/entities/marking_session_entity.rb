module Entities
  class MarkingSessionEntity < Grape::Entity
    expose :id
    expose :marker_id
    expose :unit_id
    expose :ip_address
    expose :start_time
    expose :end_time
    expose :duration_minutes
    expose :created_at
    expose :updated_at
  end
end
