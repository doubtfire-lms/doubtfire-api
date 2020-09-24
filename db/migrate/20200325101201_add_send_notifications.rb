class AddSendNotifications < ActiveRecord::Migration
  def change
    add_column :units, :send_notifications, :boolean, null: false, default: true
  end
end
