class AssessmentComment < TaskComment
  before_create do
    self.content_type = :assessment
    self.attention_audience = :student
  end

  def serialize(user)
    json = super(user)
    json[:overseer_assessment_id] = self.commentable_id
    json[:overseer_total_steps] = self.commentable.total_steps
    json[:overseer_passed_steps] = self.commentable.passed_steps
    json[:overseer_status] = self.commentable.status
    json
  end
end
