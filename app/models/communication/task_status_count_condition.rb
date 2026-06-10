class TaskStatusCountCondition < CommunicationCondition
  validates :task_status_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :task_target_grade, presence: true, inclusion: { in: GradeHelper::RANGE }
  validates :operator, inclusion: { in: GRADE_OPERATORS }
  validate :task_statuses_must_be_present
end
