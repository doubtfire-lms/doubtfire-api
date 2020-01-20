class AddReplyIdToTaskComments < ActiveRecord::Migration
  def change
    add_column :task_comments, :reply_to, :string
  end
end
