class LoginStatusCondition < CommunicationCondition
  validates :last_sign_in_at, presence: true
  validates :operator, inclusion: { in: DATE_OPERATORS }
end
