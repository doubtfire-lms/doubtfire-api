class CreateTaskInstances < ActiveRecord::Migration
  def change
    create_table :task_instances do |t|
      t.references :task
      t.references :project_membership
      t.references :task_status
      t.boolean :awaiting_signoff

      t.timestamps
    end
    add_index :task_instances, :task_id
    add_index :task_instances, :project_membership_id
    add_index :task_instances, :task_status_id
  end
end
