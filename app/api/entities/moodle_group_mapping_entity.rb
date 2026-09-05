module Entities
  class MoodleGroupMappingEntity < Grape::Entity
    expose :id
    expose :moodle_group_id
    expose :moodle_group_name
    expose :target_type
    expose :group_set_id
    expose :group_id
    expose :campus_id
    expose :tutorial_stream_id
    expose :tutorial_id
    expose :create_if_missing
  end
end
