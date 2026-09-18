class AddSubmittedPortfolioToCommunicationConditions < ActiveRecord::Migration[8.0]
  def change
    add_column :communication_conditions, :submitted_portfolio, :boolean
  end
end
