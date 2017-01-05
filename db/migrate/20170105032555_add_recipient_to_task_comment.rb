class AddRecipientToTaskComment < ActiveRecord::Migration
  def change
    add_column :task_comment, :is_new, :boolean, default: true

    add_reference :task_comment, :recipient, references: :user
    add_foreign_key :task_comment, :user, column: :recipient_id

    TaskComment.all.each do |task_comment|
      task_comment.is_new = false
    end
  end
end
