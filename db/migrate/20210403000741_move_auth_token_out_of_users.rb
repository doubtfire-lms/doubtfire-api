class MoveAuthTokenOutOfUsers < ActiveRecord::Migration[4.2]
  def up
    create_table :auth_tokens do |t|
      t.string          :encrypted_authentication_token,  null: false,  limit: 255
      t.string	        :encrypted_authentication_token_iv, limit: 255
      t.datetime        :auth_token_expiry,               null: false
    end
    add_reference   :auth_tokens, :user, index: true

    remove_column :users, :authentication_token
    remove_column :users, :auth_token_expiry
  end

  def down
    add_column :users, :authentication_token, :string,    limit: 255
    add_column :users, :auth_token_expiry,    :datetime

    drop_table :auth_tokens
  end
end
