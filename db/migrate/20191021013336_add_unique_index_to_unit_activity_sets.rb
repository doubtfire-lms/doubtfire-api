class AddUniqueIndexToUnitActivitySets < ActiveRecord::Migration
  def change
    add_index :unit_activity_sets, [:activity_type_id, :unit_id], unique: true
  end
end
