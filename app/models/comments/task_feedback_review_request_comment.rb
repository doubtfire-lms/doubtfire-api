class TaskFeedbackReviewRequestComment < TaskComment
  before_create do
    self.content_type = :feedback_review_request
    self.attention_audience = :none
  end

  def serialize(user)
    json = super(user)
    json[:recipient_read_time] = nil
    json[:date] = self.created_at
    json
  end
end
