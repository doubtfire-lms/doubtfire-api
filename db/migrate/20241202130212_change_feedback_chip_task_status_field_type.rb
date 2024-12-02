class ChangeFeedbackChipTaskStatusFieldType < ActiveRecord::Migration[7.1]
  def change
    add_reference :feedback_chips, :task_status, foreign_key: { to_table: :task_statuses }
    remove_column :feedback_chips, :task_status, :string
  end
end
