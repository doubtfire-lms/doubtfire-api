class AddGroupSetCap < ActiveRecord::Migration
  def change
    add_column :group_sets, :capacity, :integer
  end
end
