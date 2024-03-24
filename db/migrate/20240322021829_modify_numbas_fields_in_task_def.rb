class ModifyNumbasFieldsInTaskDef < ActiveRecord::Migration[7.0]
  def change
    change_table :task_definitions do |t|
      t.boolean :has_enabled_numbas_test, default: false
      t.boolean :has_numbas_time_delay, default: false
      t.integer :numbas_attempt_limit
    end
  end

  def down
    change_table :task_definitions do |t|
      t.remove :has_enabled_numbas_test
      t.remove :has_numbas_time_delay
      t.remove :numbas_attempt_limit
    end
  end
end
