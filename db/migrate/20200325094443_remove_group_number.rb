class RemoveGroupNumber < ActiveRecord::Migration
  def change
    remove_column :groups, :number
  end
end
