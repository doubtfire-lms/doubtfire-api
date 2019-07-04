class AddTypeToTaskComments < ActiveRecord::Migration
  def change
    add_column :task_comments, :type, :string
  end
end
