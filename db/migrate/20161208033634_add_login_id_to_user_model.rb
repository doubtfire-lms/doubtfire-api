class AddLoginIdToUserModel < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :login_id, :string, null: false, default: ''
    add_index :users, :login_id, unique: true
  end
end
