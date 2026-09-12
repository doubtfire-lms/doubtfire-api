class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.integer :user_id
      t.string :message

      t.timestamps
    end
  end
end
