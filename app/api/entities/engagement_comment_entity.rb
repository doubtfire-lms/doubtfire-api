module Entities
  class EngagementCommentEntity < Grape::Entity
    expose :id
    expose :comment
    expose :user, using: Entities::Minimal::MinimalUserEntity
    expose :created_at
    expose :updated_at
  end
end
