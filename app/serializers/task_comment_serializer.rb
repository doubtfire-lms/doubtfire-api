class TaskCommentSerializer < ActiveModel::Serializer
  attributes :id, :comment, :created_at, :comment_by

  def comment_by
    object.user.name
  end
end
