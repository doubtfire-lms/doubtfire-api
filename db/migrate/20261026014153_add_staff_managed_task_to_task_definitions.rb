class AddStaffManagedTaskToTaskDefinitions < ActiveRecord::Migration[8.0]
  def change
    add_column :task_definitions, :staff_managed_task, :boolean, default: false, null: false
  end
end
