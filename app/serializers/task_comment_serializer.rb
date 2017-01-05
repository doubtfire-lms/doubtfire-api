class TaskCommentSerializer < ActiveModel::Serializer
  attributes :id, :comment, :created_at, :comment_by, :recipient_id, :is_new

  def comment_by
    object.user.name
  end
end
