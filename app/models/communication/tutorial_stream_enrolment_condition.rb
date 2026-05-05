class TutorialStreamEnrolmentCondition < CommunicationCondition
  validates :tutorial_stream, presence: true
  validates :operator, inclusion: { in: ENROLMENT_OPERATORS }
end
