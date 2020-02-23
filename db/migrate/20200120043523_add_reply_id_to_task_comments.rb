class AddReplyIdToTaskComments < ActiveRecord::Migration
  def change
    add_reference :task_comments, :reply_to, index: true
  end
end
