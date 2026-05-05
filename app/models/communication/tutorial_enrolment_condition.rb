class TutorialEnrolmentCondition < CommunicationCondition
  validates :tutorial, presence: true
  validates :operator, inclusion: { in: ENROLMENT_OPERATORS }
end
