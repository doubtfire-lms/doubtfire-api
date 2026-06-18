module Entities
  class EngagementDetailEntity < EngagementEntity
    expose :engagement_comments,
           as: :comments,
           using: Entities::EngagementCommentEntity
  end
end
