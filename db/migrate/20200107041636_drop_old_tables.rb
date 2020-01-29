class DropOldTables < ActiveRecord::Migration
  def change
    drop_table :sub_task_definitions
    drop_table :sub_tasks
    drop_table :badges
  end
end
