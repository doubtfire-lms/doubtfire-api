class LoginStatusCondition < CommunicationCondition
  validates :activity_days,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :operator, inclusion: { in: ACTIVITY_OPERATORS }
end
