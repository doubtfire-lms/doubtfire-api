class AddActiveToCampuses < ActiveRecord::Migration
  def change
    add_column :campuses, :active, :boolean, :null => false
    add_index :campuses, :active
  end
end
