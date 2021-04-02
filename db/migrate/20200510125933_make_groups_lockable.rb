class MakeGroupsLockable < ActiveRecord::Migration
  def change
    add_column :groups, :locked, :boolean, default: false, null: false
  end
end
