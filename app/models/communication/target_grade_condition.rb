class TargetGradeCondition < CommunicationCondition
  validates :target_grade, presence: true
  validates :operator, inclusion: { in: GRADE_OPERATORS }
end
