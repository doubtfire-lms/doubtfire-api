module Entities
  class CommunicationSetScheduleEntity < Grape::Entity
    expose :id
    expose :communication_set_id
    expose :name
    expose :active
    expose :anchor_week
    expose :anchor_day
    expose :hour
    expose :minute
    expose :timezone
    expose :recurrence
    expose :interval
    expose :repeat_count
    expose :until_at
    expose :ice_cube_schedule
    expose :next_run_at
    expose :last_run_at
    expose :last_enqueued_at
  end
end
