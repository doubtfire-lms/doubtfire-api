class CommunicationAction < ApplicationRecord
  VALID_TYPES = %w[
    EmailStudentAction
    EmailStaffAction
    ChangeTargetGradeAction
  ].freeze

  belongs_to :communication_rule, class_name: 'CommunicationRule'

  validates :type, presence: true, inclusion: { in: VALID_TYPES }
end
