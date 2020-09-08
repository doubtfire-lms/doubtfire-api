class AddPortfolioAutoGenerationDateToUnits < ActiveRecord::Migration
  def change
    add_column :units, :portfolio_auto_generation_date, :datetime
  end
end
