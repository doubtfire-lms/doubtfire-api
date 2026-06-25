module Entities
  class EngagementEntity < Grape::Entity
    expose :id
    expose :project_id
    expose :engagement_type
    expose :note
    expose :occurred_at
    expose :evidence_url
    expose :content_type
    expose :has_attachment do |engagement, _options|
      engagement.attachment?
    end
    expose :attachment_file_name, if: ->(engagement, _) { engagement.attachment? }
    expose :user, using: Entities::Minimal::MinimalUserEntity
    expose :comment_count do |engagement|
      engagement.engagement_comments.size
    end
    expose :created_at
    expose :updated_at
  end
end
