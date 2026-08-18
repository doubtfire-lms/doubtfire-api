class CampusCondition < CommunicationCondition
  validates :campus, presence: true, unless: :unresolved_reference?
  validates :operator, inclusion: { in: ENROLMENT_OPERATORS }
end
