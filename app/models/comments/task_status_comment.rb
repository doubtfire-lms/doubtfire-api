class TaskStatusComment < TaskComment

  belongs_to :task_status

  before_create do
    self.content_type = :status
  end

  # Ensure status changes are not notified to staff - they get the task
  # when it is ready for feedback
  after_create do
    if self.user == project.student
      mark_as_read(self.recipient)
    end
  end

  def serialize(user)
    json = super(user)
    json[:date] = self.created_at
    json[:status] = task_status.status_key
    json
  end

end
