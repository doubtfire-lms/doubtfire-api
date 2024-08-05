class ScormComment < TaskComment
  belongs_to :test_attempt, optional: false

  before_create do
    self.content_type = :scorm
  end

  def serialize(user)
    json = super(user)
    json[:test_attempt] = {
      id: self.test_attempt_id,
      success_status: self.test_attempt.success_status
    }
    json
  end
end
