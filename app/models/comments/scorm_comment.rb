class ScormComment < TaskComment
  before_create do
    self.content_type = :scorm
  end

  def serialize(user)
    json = super(user)
    json[:test_attempt] = {
      id: self.commentable_id,
      success_status: self.commentable.success_status
    }
    json
  end
end
