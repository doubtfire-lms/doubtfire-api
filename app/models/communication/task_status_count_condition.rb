class TaskStatusCountCondition < CommunicationCondition
  validates :task_status_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :task_target_grade, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :operator, inclusion: { in: GRADE_OPERATORS }
  validate :task_statuses_must_be_present
  validate :task_target_grade_enabled_for_unit

  private

  def task_target_grade_enabled_for_unit
    return if task_target_grade.nil? || communication&.unit&.grade_value?(task_target_grade)

    errors.add(:task_target_grade, 'is not enabled for this unit')
  end
end
