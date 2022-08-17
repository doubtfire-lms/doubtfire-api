class PortfolioAutomation < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :portfolio_auto_generated, :boolean, default: false, null: false
    add_column :units, :portfolio_auto_generation_date, :datetime
  end

end
