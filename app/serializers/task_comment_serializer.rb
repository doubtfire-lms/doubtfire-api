class TaskCommentSerializer < ActiveModel::Serializer
  attributes :id, :comment, :created_at, :comment_by, :is_new

  def comment_by
    object.user.name
  end
end
