class AddRecipientToTaskComment < ActiveRecord::Migration
  def change
    add_column :task_comment, :is_new, :boolean, default: true

    # this is the same as add_reference but allows you to specify name of field. (recipient)
    add_column :task_comment, :recipient, :integer
    add_index :task_comment, :recipient

    TaskComment.all.each do |task_comment|
      task_comment.is_new = false
    end
  end
end
