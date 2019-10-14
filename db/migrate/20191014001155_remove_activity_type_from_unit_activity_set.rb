class RemoveActivityTypeFromUnitActivitySet < ActiveRecord::Migration
  def change
    remove_column :unit_activity_sets, :activity_type
  end
end
