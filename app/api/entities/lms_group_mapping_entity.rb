module Entities
  class LmsGroupMappingEntity < Grape::Entity
    expose :id
    expose :lms_group_id
    expose :lms_group_name
    expose :target_type
    expose :group_set_id
    expose :group_id
    expose :campus_id
    expose :tutorial_stream_id
    expose :tutorial_id
    expose :create_if_missing
  end
end
