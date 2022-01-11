module Entities
  class GroupMembershipEntity < Grape::Entity
    expose :group_id
    expose :project_id
  end
end
