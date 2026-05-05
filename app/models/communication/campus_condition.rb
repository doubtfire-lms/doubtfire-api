class CampusCondition < CommunicationCondition
  validates :campus, presence: true
  validates :operator, inclusion: { in: ENROLMENT_OPERATORS }
end
