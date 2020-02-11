class TaskCommentSerializer < HashSerializer
  class AuthorSerializer < HashSerializer
    attributes :id, :name, :email
  end

  attributes :id, 
    :comment,
    :has_attachment,
    :type,
    :is_new,
    :created_at,
    :recipient_read_time
  has_one :author, serializer: TaskCommentSerializer::AuthorSerializer
  has_one :recipient, serializer: TaskCommentSerializer::AuthorSerializer
end