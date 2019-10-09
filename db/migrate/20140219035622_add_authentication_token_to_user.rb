class AddAuthenticationTokenToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :authentication_token, :string
    add_index :users, :authentication_token, unique: true
  end
end
