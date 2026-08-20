class CommunicationAction < ApplicationRecord
  VALID_TYPES = %w[
    EmailStudentAction
    EmailStaffAction
    ChangeTargetGradeAction
    TaskCommentAction
  ].freeze

  # The unit-scoped record each action type cannot be performed without.
  REQUIRED_REFERENCES = { 'TaskCommentAction' => :task_definition }.freeze

  belongs_to :communication_rule, class_name: 'CommunicationRule'
  belongs_to :task_definition, optional: true

  validates :type, presence: true, inclusion: { in: VALID_TYPES }

  def required_reference
    REQUIRED_REFERENCES[type]
  end

  # See CommunicationCondition#unresolved? -- an action pointing at a task from
  # another unit would comment on the wrong task, or on nothing at all.
  def unresolved?
    reference = required_reference
    return false if reference.nil?

    target = public_send(reference)
    target.blank? || target.unit_id != communication_rule.unit_id
  end
end
