class AddRestrictTaskStatusUpdates < ActiveRecord::Migration[4.2]
  def change
  	add_column :task_definitions, :restrict_status_updates, :boolean, default: false
  end
end
