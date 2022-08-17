class PortfolioAutomation < ActiveRecord::Migration[7.0]
  def up
    add_column :projects, :portfolio_auto_generated, :boolean, default: false, null: false
    add_column :units, :portfolio_auto_generation_date, :datetime

    execute(<<-SQL.squish)
      UPDATE units
      SET portfolio_auto_generation_date = end_date - INTERVAL 3 DAY
    SQL

    change_column_null :units, :portfolio_auto_generation_date, false
  end

  def down
    remove_column :projects, :portfolio_auto_generated
    remove_column :units, :portfolio_auto_generation_date
  end
end
