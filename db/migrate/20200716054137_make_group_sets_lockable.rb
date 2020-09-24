class MakeGroupSetsLockable < ActiveRecord::Migration
  def change
    add_column :group_sets, :locked, :boolean, default: false, null: false
  end
end
