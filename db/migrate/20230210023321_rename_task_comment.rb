class RenameTaskComment < ActiveRecord::Migration[7.0]
  def change
    rename_table :task_comments, :messages

    Message.where(type: nil).update_all(type: 'TaskComment')
  end
end
