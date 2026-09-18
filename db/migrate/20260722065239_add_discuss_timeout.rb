class AddDiscussTimeout < ActiveRecord::Migration[8.0]
  def change
    add_column :units, :discuss_timeout_enabled, :boolean, null: false, default: false
    add_column :units, :discuss_timeout_warning_days, :integer, null: false, default: 7
    add_column :units, :discuss_timeout_expire_days, :integer, null: false, default: 14
    add_column :tasks, :moved_to_discuss_at, :datetime
    add_column :tasks, :notified_discuss_warning_at, :datetime
    add_column :tasks, :notified_discuss_expiry_at, :datetime

    add_index :tasks, [:task_status_id, :moved_to_discuss_at]
    add_index :tasks, [:task_status_id, :notified_discuss_warning_at]
    add_index :tasks, [:task_status_id, :notified_discuss_expiry_at]
  end
end
