class AddAuthTokenType < ActiveRecord::Migration[7.1]
  def change
    add_column :auth_tokens, :token_type, :string, null: false
  end
end
