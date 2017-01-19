class TaskCommentSerializer < ActiveModel::Serializer
  attributes :id, :comment, :created_at, :author, :recipient

  def author
    {
      id: object.user.id,
      name: object.user.name,
    }
  end

  def recipient
    {
      id: object.recipient.id,
      name: object.recipient.name,
    }
  end
end
