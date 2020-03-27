class AddGroupCapacityAdjustment < ActiveRecord::Migration
  def change
    add_column :groups, :capacity_adjustment, :integer, null: false, default: 0
  end
end
