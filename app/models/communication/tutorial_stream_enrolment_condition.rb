class TutorialStreamEnrolmentCondition < CommunicationCondition
  validates :tutorial_stream, presence: true, unless: :unresolved_reference?
  validates :operator, inclusion: { in: ENROLMENT_OPERATORS }
end
