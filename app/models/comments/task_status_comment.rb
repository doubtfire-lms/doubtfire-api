class TaskStatusComment < TaskComment

  belongs_to :task_status

  before_create do
    self.content_type = :status
  end

  def serialize(user)
    json = super(user)
    json[:date] = self.created_at
    json[:status] = task_status.status_key
    json
  end

end
