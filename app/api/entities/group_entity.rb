module Entities
  class GroupEntity < Grape::Entity
    expose :id
    expose :name
    expose :tutorial_id
    expose :group_set_id
    expose :student_count # TODO: remove this and request it dynamically when needed
    expose :capacity_adjustment
    expose :locked
  end
end
