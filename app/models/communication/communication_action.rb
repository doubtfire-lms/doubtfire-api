class CommunicationAction < ApplicationRecord
  VALID_TYPES = %w[
    EmailStudentAction
    EmailStaffAction
    ChangeTargetGradeAction
    TaskCommentAction
  ].freeze

  belongs_to :communication_rule, class_name: 'CommunicationRule'
  belongs_to :task_definition, optional: true

  validates :type, presence: true, inclusion: { in: VALID_TYPES }
end
