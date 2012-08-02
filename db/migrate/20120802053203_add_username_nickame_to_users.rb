class AddUsernameNickameToUsers < ActiveRecord::Migration
  def change
    add_column :users, :username, :string
    add_column :users, :nickname, :string
  end
end
