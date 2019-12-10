class AddNotificationSettings < ActiveRecord::Migration[4.2]
  def change
  	add_column :users, :receive_task_notifications, :boolean, default: true
  	add_column :users, :receive_feedback_notifications, :boolean, default: true
  	add_column :users, :receive_portfolio_notifications, :boolean, default: true
  end
end
