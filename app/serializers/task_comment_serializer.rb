class TaskCommentSerializer < ActiveModel::Serializer
  attributes :id, :comment, :has_attachment, :type, :created_at, :author, :recipient, :recipient_read_time

  def has_attachment
    %w(audio image pdf).include?(object.content_type)
  end

  def type
    object.content_type || 'text'
  end

  def is_new
    new_for?(Thread.current[:user])
  end

  def author
    {
      id: object.user.id,
      name: object.user.name,
      email: object.user.email
    }
  end

  def recipient
    {
      id: object.recipient.id,
      name: object.recipient.name,
      email: object.user.email
    }
  end

  def recipient_read_time
    object.time_read_by(object.recipient)
  end
end