class PortfolioSubmittedCondition < CommunicationCondition
  validates :submitted_portfolio, inclusion: { in: [true, false] }
  validates :operator, inclusion: { in: EQUALITY_OPERATORS }
end
