class AddPortfolioProductionDate < ActiveRecord::Migration[4.2]
  def change
  	add_column :projects, :portfolio_production_date, :date
  end
end
