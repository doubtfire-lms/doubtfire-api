module Entities
  class GroupSetEntity < Grape::Entity
    expose :id
    expose :name
    expose :allow_students_to_create_groups
    expose :allow_students_to_manage_groups
    expose :keep_groups_in_same_class
    expose :capacity
    expose :locked
  end
end
