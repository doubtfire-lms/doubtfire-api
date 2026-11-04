class AddObserveAllUnitsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :observe_all_units, :boolean, default: false, null: false
  end
end
