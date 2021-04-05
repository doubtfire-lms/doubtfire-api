class AddGroupNumber < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :number, :integer, null: false, unique: true
  end
end
