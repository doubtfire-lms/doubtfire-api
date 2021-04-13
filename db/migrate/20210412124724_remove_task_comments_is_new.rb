class RemoveTaskCommentsIsNew < ActiveRecord::Migration[6.1]
  def change
    remove_column :task_comments, :is_new, :boolean
  end
end
