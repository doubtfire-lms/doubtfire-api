class ModifyNumbasFieldsInTaskDef < ActiveRecord::Migration[7.0]
  def change
    change_table :task_definitions do |t|
      t.boolean :has_enabled_numbas_test, default: false
      t.boolean :has_unlimited_retries_for_numbas, default: false
      t.boolean :has_time_delay_for_numbas, default: false
      t.boolean :is_numbas_restricted_to_1_attempt, default: false
      t.string :numbas_time_delay
    end
  end

  def down
    change_table :task_definitions do |t|
      t.remove :has_enabled_numbas_test
      t.remove :has_unlimited_retries_for_numbas
      t.remove :has_time_delay_for_numbas
      t.remove :is_numbas_restricted_to_1_attempt
      t.remove :numbas_time_delay
    end
  end
end
