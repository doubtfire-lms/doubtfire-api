class TaskDiscussedComment < TaskComment
  before_create do
    self.content_type = :discussed_in_class
  end

  after_create do
    mark_as_read(self.recipient)
  end

  def serialize(user)
    json = super(user)
    json[:recipient_read_time] = nil
    json[:date] = self.created_at
    json
  end
end
