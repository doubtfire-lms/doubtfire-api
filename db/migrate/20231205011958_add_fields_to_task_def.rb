class AddFieldsToTaskDef < ActiveRecord::Migration[7.0]
  def change
    change_table :task_definitions do |t|
      t.boolean :has_test, default: false
      t.boolean :restrict_attempts, default: false
      t.integer :delay_restart_minutes
      t.boolean :retake_on_resubmit, default: false
    end
  end

  def down
    change_table :task_definitions do |t|
      t.remove :has_test
      t.remove :restrict_attempts
      t.remove :delay_restart_minutes
      t.remove :retake_on_resubmit
    end
  end
end
