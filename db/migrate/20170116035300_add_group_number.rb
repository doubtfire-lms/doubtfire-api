class AddGroupNumber < ActiveRecord::Migration
  def change
    add_column :groups, :group_number, :integer, null: false, unique: true
  end
end
