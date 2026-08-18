class TutorialEnrolmentCondition < CommunicationCondition
  validates :tutorial, presence: true, unless: :unresolved_reference?
  validates :operator, inclusion: { in: ENROLMENT_OPERATORS }
end
