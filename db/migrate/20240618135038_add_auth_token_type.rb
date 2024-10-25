class AddAuthTokenType < ActiveRecord::Migration[7.1]
  def change
    add_column :auth_tokens, :token_type, :integer, null: false, default: 0
    add_index :auth_tokens, :token_type
  end
end
