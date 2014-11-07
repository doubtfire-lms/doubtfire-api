class AddPortfolioProductionDate < ActiveRecord::Migration
  def change
  	add_column :projects, :portfolio_production_date, :date
  end
end
