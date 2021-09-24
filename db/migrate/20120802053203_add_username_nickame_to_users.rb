class AddUsernameNickameToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :username, :string
    add_column :users, :nickname, :string
  end
end
