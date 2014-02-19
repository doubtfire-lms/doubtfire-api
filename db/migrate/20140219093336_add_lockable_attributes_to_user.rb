class AddLockableAttributesToUser < ActiveRecord::Migration
  def change
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :unlock_token, :string
    add_column :users, :locked_at, :datetime
    add_column :users, :auth_token_expiry, :datetime
  end
end
