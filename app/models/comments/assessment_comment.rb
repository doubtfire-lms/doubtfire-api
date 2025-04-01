class AssessmentComment < TaskComment
  before_create do
    self.content_type = :assessment
  end

  def serialize(user)
    json = super(user)
    json[:overseer_assessment_id] = self.commentable_id
    json
  end
end
