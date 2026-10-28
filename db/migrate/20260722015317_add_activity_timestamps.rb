class AddActivityTimestamps < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_access_at, :datetime
    add_column :projects, :last_viewed_at, :datetime
  end
end
