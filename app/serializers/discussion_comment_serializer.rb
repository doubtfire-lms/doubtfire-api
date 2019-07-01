class DiscussionCommentSerializer < ActiveModel::Serializer
  attributes :id, :task_comment_id, :status, :time_completed, :time_started, :updated_at
  def status
    object.status
  end
end
