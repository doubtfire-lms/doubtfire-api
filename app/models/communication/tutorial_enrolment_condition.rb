class TutorialEnrolmentCondition < CommunicationCondition
  validates :operator, inclusion: { in: ENROLMENT_OPERATORS }
end
