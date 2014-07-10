class RemoveUserAccountLocking < ActiveRecord::Migration
  def change
  	remove_column :users, :failed_attempts
  	remove_column :users, :locked_at
  end
end
