class TargetGradeCondition < CommunicationCondition
  validates :target_grade, presence: true
  validates :operator, inclusion: { in: GRADE_OPERATORS }
  validate :target_grade_enabled_for_unit

  private

  def target_grade_enabled_for_unit
    return if target_grade.nil? || communication&.unit&.grade_value?(target_grade)

    errors.add(:target_grade, 'is not enabled for this unit')
  end
end
