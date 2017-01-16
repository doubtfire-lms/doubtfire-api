class AddGroupNumber < ActiveRecord::Migration
  def change
    add_column :groups, :number, :integer, null: false, unique: true
  end
end
