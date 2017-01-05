class AddRecipientToTaskComment < ActiveRecord::Migration
  def change
    add_column :task_comments, :is_new, :boolean, default: true

    add_reference :task_comments, :recipient, references: :users
    add_foreign_key :task_comments, :users, column: :recipient_id

    TaskComment.update_all(is_new: false)
  end
end
