class AddReplyIdToTaskComments < ActiveRecord::Migration
  def change
    add_column :task_comments, :reply_to, :integer
  end
end
