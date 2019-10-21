class AddUniqueIndexToCampusActivitySets < ActiveRecord::Migration
  def change
    add_index :campus_activity_sets, [:unit_activity_set_id, :campus_id], name: 'unique_index_on_campus_and_unit_activity_sets', unique: true
  end
end
