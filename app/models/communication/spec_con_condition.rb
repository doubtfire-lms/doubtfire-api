class SpecConCondition < CommunicationCondition
  validates :spec_con_days, presence: true, numericality: { only_integer: true }
  validates :operator, inclusion: { in: GRADE_OPERATORS }
end
