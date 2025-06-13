class AddSpecCon < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :spec_con_days, :integer, default: 0, null: false
    add_column :units, :allow_flexible_dates, :boolean, default: false, null: false
    add_column :units, :portfolio_due_date, :datetime
  end
end
