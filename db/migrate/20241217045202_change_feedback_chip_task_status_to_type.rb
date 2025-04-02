class ChangeFeedbackChipTaskStatusToType < ActiveRecord::Migration[7.1]
  def change
    add_column :feedback_chips, :task_status, :string
    remove_column :feedback_chips, :task_status_id, :bigint
  end
end
