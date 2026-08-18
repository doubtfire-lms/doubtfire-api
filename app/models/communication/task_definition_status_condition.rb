class TaskDefinitionStatusCondition < CommunicationCondition
  validates :task_definition, presence: true, unless: :unresolved_reference?
  validates :operator, inclusion: { in: EQUALITY_OPERATORS }
  validate :task_statuses_must_be_present
end
