class RenameTypeInUnitActivitySet < ActiveRecord::Migration
  def change
    rename_column :unit_activity_sets, :type, :activity_type
  end
end
