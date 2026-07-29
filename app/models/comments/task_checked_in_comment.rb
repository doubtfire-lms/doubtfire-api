class TaskCheckedInComment < TaskComment
  before_create do
    self.content_type = :checked_in
    self.attention_audience = :none
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
