class AddTypeToTaskComments < ActiveRecord::Migration[4.2]
  def change
    add_column :task_comments, :type, :string
  end
end
