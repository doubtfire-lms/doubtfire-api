class AssessmentComment < TaskComment
  belongs_to :overseer_assessment, optional: false

  before_create do
    self.content_type = :assessment
  end

  def serialize(user)
    json = super(user)
    json[:overseer_assessment_id] = self.overseer_assessment_id
    json
  end
end
